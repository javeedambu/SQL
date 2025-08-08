---

### **Executive Summary: Kerberos Delegation Challenges with SSIS and Linked Servers**

In a SQL Server integration environment spanning three servers (ServerA → ServerB → ServerC), Kerberos authentication fails in a double-hop scenario when using SSIS and linked servers due to limitations in constrained delegation and Windows Credential Guard.

#### 🔑 Key Points:

* **Multihop Scenario:**
  SSIS packages run on **ServerA**, connect to **ServerB**, which then connects via a linked server to **ServerC**. This is a classic **double-hop (multi-hop)** Kerberos authentication case.

* **Credential Guard Implications:**
  Credential Guard, enabled by default on newer Windows Server versions, blocks the use of **unconstrained delegation**, requiring **constrained delegation** to perform multi-hop authentication securely.

* **SSIS Limitation:**
  SSIS does **not support constrained delegation properly** because it does **not propagate Kerberos tokens** across hops, even if service accounts are configured correctly. Therefore, Kerberos authentication fails at the **linked server hop** from ServerB to ServerC.

* **Current Setup:**

  * All SQL Engines run under individual service accounts: `SQLA_SVC`, `SQLB_SVC`, `SQLC_SVC`
  * SSIS packages use `SSIS_SVC` for authentication

#### ⚠️ Problem:

Even with constrained delegation configured on `SQLB_SVC`, ServerB cannot forward credentials from `SSIS_SVC` to ServerC over the linked server. This is a known Microsoft limitation in SSIS architecture when Credential Guard is present.

---

### ✅ Recommended Options:

1. **Use SQL Authentication** in the linked server to avoid Kerberos delegation altogether.
2. **Redesign SSIS Package** to connect directly from **ServerA to ServerC**, avoiding the second hop.
3. **Disable Credential Guard** on **ServerA and ServerB** (with security caveats), allowing **unconstrained delegation**.
4. **Rehost on Project Deployment Model (SSISDB)** where the job runs **locally via SQL Agent**, which may support Kerberos under constrained delegation *if no linked server is used*.

---


---
---

**Title:** Challenges with Kerberos Constrained Delegation, Credential Guard, and SSIS in Multi-Hop SQL Server Scenarios

**Author:** \[Your Name]
**Date:** \[Insert Date]

---

### **1. Introduction**

In enterprise ETL environments, SQL Server Integration Services (SSIS) is frequently used to orchestrate data movement across multiple servers. With the growing emphasis on security, modern Windows Server deployments often include features like Credential Guard, which can impact traditional Kerberos-based authentication flows. This paper explores the challenges encountered in a multi-hop scenario involving SSIS, Credential Guard, and Kerberos constrained delegation, and outlines potential solutions.

---

### **2. Scenario Overview**

We consider a real-world deployment involving three SQL Server instances:

| Server  | SQL Version     | Service Account  |
| ------- | --------------- | ---------------- |
| ServerA | SQL Server 2022 | DOMAIN\SQLA\_SVC |
| ServerB | SQL Server 2022 | DOMAIN\SQLB\_SVC |
| ServerC | SQL Server 2019 | DOMAIN\SQLC\_SVC |

* **SSIS is installed and executed on ServerA**.
* **98% of the ETL uses the Package Deployment Model**, while **2% uses the Project Deployment Model** (via SSISDB).
* A specific **package (in package deployment model)** on ServerA connects to ServerB using the **DOMAIN\SSIS\_SVC** account.
* On ServerB, a stored procedure is invoked that connects to ServerC using a **linked server**.

This is a **multi-hop scenario** involving the following authentication flow:

1. SSIS on ServerA (running as SSIS\_SVC) connects to SQL Server on ServerB.
2. SQL Server on ServerB (running as SQLB\_SVC) uses a linked server to connect to SQL Server on ServerC.

---

### **3. Why This is a Multi-Hop Scenario**

A **Kerberos double-hop (multi-hop)** scenario occurs when:

* The original client (SSIS on ServerA) authenticates to a server (ServerB), and then
* That server (ServerB) tries to access another service (SQL on ServerC) **on behalf of the original user**.

Since linked servers typically use the "current login's security context," ServerB must impersonate the SSIS\_SVC account to connect to ServerC.

---

### **4. The Role of Credential Guard**

**Credential Guard** isolates and secures credentials using virtualization-based security. However, this breaks traditional delegation models by:

* Preventing storage of Kerberos TGTs in LSASS.
* Blocking **unconstrained delegation**.

Thus, in environments with Credential Guard enabled, **only constrained delegation** is supported for multi-hop authentication.

**Reference:**
Microsoft Docs: [You can't use Kerberos unconstrained delegation in certain versions of Windows](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/connect/windows-prevents-unconstrained-delegation)

---

### **5. SSIS and Delegation Limitations**

According to Microsoft:

> "The architecture of SSIS prevents it from being used with constrained delegation."
> "Launching the jobs from a local SQL Agent should be fine as long as the back-end databases don't use linked servers."

This is because:

* SSIS packages do **not pass the Kerberos token** from the execution context across servers.
* Even if the SSIS\_SVC account is configured for constrained delegation, the token isn't preserved through the SSIS runtime (e.g., ISServerExec.exe or dtexec.exe).

---

### **6. Why Constrained Delegation Fails in This Case**

Even if you configure constrained delegation properly:

* SQLB\_SVC (on ServerB) does not receive a usable Kerberos token to impersonate SSIS\_SVC.
* Therefore, ServerB fails when trying to use the linked server to ServerC.

This is due to:

* Lack of token propagation in SSIS.
* Credential Guard blocking any fallback to unconstrained delegation.

---

### **7. Possible Workarounds and Fixes**

#### **A. Use SQL Authentication in Linked Server**

* Bypasses Kerberos entirely.
* Configure the linked server on ServerB to connect to ServerC using a SQL login.
* Most reliable short-term fix.

#### **B. Redesign SSIS to Connect Directly to ServerC**

* Avoid the double-hop entirely.
* Have SSIS connect to both ServerB and ServerC directly.

#### **C. Use the Project Deployment Model (SSISDB) Locally**

* If run via SQL Agent on ServerA, avoid remote execution.
* Ensure packages are executed **locally** by SQL Agent, not from remote SSMS.

#### **D. Disable Credential Guard (Security Tradeoff)**

Only disable if strictly required, and understand the implications.

| Server  | Disable Credential Guard? | Reason                                             |
| ------- | ------------------------- | -------------------------------------------------- |
| ServerA | ✅ Yes                     | Needs to allow Kerberos tickets to flow to ServerB |
| ServerB | ✅ Yes                     | Needs to impersonate SSIS\_SVC to ServerC          |
| ServerC | ❌ No                      | Target server; doesn’t delegate                    |

#### **E. Use SQL Agent Proxies (Advanced)**

* Configure SQL Agent jobs with proxy accounts that have permission to execute SSIS packages and access remote servers.

#### **F. Consider Managed Identity (Azure Hybrid)**

* If hybrid/cloud-connected, use Azure AD and managed identities to authenticate without delegation.

---

### **8. Conclusion**

In modern Windows environments with Credential Guard enabled, **SSIS cannot reliably support multi-hop authentication scenarios using constrained delegation**, especially when linked servers are involved. The limitations stem from both **Credential Guard security constraints** and **SSIS's internal architecture**, which fails to propagate Kerberos tokens properly.

Organizations must choose between workarounds like **SQL authentication**, **direct connections**, or **disabling Credential Guard** (with caution). Proper architectural decisions, including SSIS package design and deployment model choices, can significantly improve security and reliability.

---

### **References**

1. Microsoft Docs - [Kerberos Delegation and Credential Guard](https://learn.microsoft.com/en-us/troubleshoot/sql/database-engine/connect/windows-prevents-unconstrained-delegation)
2. Microsoft Docs - [SSIS and Kerberos Delegation](https://learn.microsoft.com/en-us/sql/integration-services/security/ssis-and-kerberos-authentication)
3. Microsoft - [Credential Guard Overview](https://learn.microsoft.com/en-us/windows/security/identity-protection/credential-guard/credential-guard)
4. Kerberos Authentication Flow - [Microsoft Docs](https://learn.microsoft.com/en-us/windows-server/security/kerberos/kerberos-authentication-overview)

---
---

---
Detailed instructions — both **PowerShell** and **GUI** — for configuring **Service Principal Names (SPNs)** and **Constrained Delegation** for your multi-hop SSIS + SQL Server scenario.

---

## 🔧 PART 1: Registering SPNs

SPNs are essential for Kerberos authentication. Each SQL Server service running under a domain account must have an SPN registered for:

```
MSSQLSvc/<FQDN>:<port>
MSSQLSvc/<hostname>:<port>
```

---

### ✅ PowerShell Instructions: Add SPNs

Use this to register SPNs for each SQL Server service account:

```powershell
# Example: SQL Server on ServerA running under DOMAIN\SQLA_SVC
setspn -S MSSQLSvc/ServerA.domain.com:1433 DOMAIN\SQLA_SVC
setspn -S MSSQLSvc/ServerA:1433 DOMAIN\SQLA_SVC

# SQL Server on ServerB
setspn -S MSSQLSvc/ServerB.domain.com:1433 DOMAIN\SQLB_SVC
setspn -S MSSQLSvc/ServerB:1433 DOMAIN\SQLB_SVC

# SQL Server on ServerC
setspn -S MSSQLSvc/ServerC.domain.com:1433 DOMAIN\SQLC_SVC
setspn -S MSSQLSvc/ServerC:1433 DOMAIN\SQLC_SVC
```

To verify:

```powershell
# View SPNs for SQLB_SVC
setspn -L DOMAIN\SQLB_SVC
```

---

### 🖥️ GUI Instructions: Add SPNs (via ADSI Edit)

1. Open **ADSI Edit** → Connect to **Default Naming Context**.
2. Navigate to the **service account object** (e.g., `DOMAIN\SQLB_SVC`).
3. Right-click → **Properties**.
4. Find the attribute `servicePrincipalName` → Edit.
5. Add:

   ```
   MSSQLSvc/ServerB.domain.com:1433
   MSSQLSvc/ServerB:1433
   ```

Repeat for other service accounts.

---

## 🔐 PART 2: Configure Constrained Delegation

Configure **constrained delegation** so the SSIS service account (`SSIS_SVC`) can delegate credentials to the SQL Server service on ServerC.

---

### ✅ PowerShell Instructions: Configure Delegation

Use this command to allow constrained delegation:

```powershell
# Allow SSIS_SVC to delegate to SQLC_SVC's MSSQL service
Set-ADUser -Identity SSIS_SVC -PrincipalsAllowedToDelegateToAccount (Get-ADComputer -Identity ServerC)

# Or allow SQLB_SVC to delegate on behalf of SSIS_SVC (if using proxy on ServerB)
Set-ADUser -Identity SQLB_SVC -Add @{msDS-AllowedToDelegateTo=@("MSSQLSvc/ServerC.domain.com:1433", "MSSQLSvc/ServerC:1433")}
```

> 🛑 `Set-ADUser` requires the **ActiveDirectory** module.

---

### 🖥️ GUI Instructions: Constrained Delegation

1. Open **Active Directory Users and Computers (ADUC)**.
2. Find the **account performing delegation** (e.g., `SSIS_SVC` or `SQLB_SVC`).
3. Right-click → **Properties** → **Delegation** tab.
4. Select:

   * ✅ "Trust this user for delegation to specified services only"
   * ✅ "Use Kerberos only"
5. Click **Add...**
6. Select **User or Computer** → Enter `ServerC` → OK
7. Choose the **MSSQLSvc** service (you must have SPNs already registered!)

---

## 📌 Notes

* Ensure **SPNs are not duplicated** across accounts.
* For **SSIS execution**, use SQL Agent with proxy if needed.
* To make Kerberos authentication easier to debug, enable auditing:

  ```powershell
  auditpol /set /subcategory:"Kerberos Authentication Service" /success:enable /failure:enable
  ```

  Then review the event logs on each server.

---
---

---
**Deployment Checklist** for enabling **Kerberos Constrained Delegation** with **SSIS + Linked Server** in your **ServerA → ServerB → ServerC** scenario.
---

## ✅ **Kerberos Constrained Delegation Deployment Checklist**

### 🔹 **A. Prerequisites**

* [ ] All servers (ServerA, ServerB, ServerC) are joined to the same Active Directory domain.
* [ ] All SQL Server services run under domain service accounts:

  * ServerA → `DOMAIN\SQLA_SVC`
  * ServerB → `DOMAIN\SQLB_SVC`
  * ServerC → `DOMAIN\SQLC_SVC`
* [ ] SSIS packages use `DOMAIN\SSIS_SVC` for authentication.
* [ ] Port 1433 (or custom SQL ports) is known and open between the servers.

---

### 🔹 **B. SPN Configuration**

#### 🔸 For each SQL Server service account:

**Run this PowerShell as a Domain Admin:**

```powershell
# For ServerA
setspn -S MSSQLSvc/ServerA.domain.com:1433 DOMAIN\SQLA_SVC
setspn -S MSSQLSvc/ServerA:1433 DOMAIN\SQLA_SVC

# For ServerB
setspn -S MSSQLSvc/ServerB.domain.com:1433 DOMAIN\SQLB_SVC
setspn -S MSSQLSvc/ServerB:1433 DOMAIN\SQLB_SVC

# For ServerC
setspn -S MSSQLSvc/ServerC.domain.com:1433 DOMAIN\SQLC_SVC
setspn -S MSSQLSvc/ServerC:1433 DOMAIN\SQLC_SVC
```

* [ ] SPNs are **unique** (no duplication across accounts)
* [ ] SPNs are registered on the **domain service account**, not the computer object

---

### 🔹 **C. Configure Constrained Delegation**

#### 🔸 Delegate from `SQLB_SVC` to `SQLC_SVC` (most critical step):

**Option 1 – PowerShell:**

```powershell
Set-ADUser -Identity SQLB_SVC -Add @{msDS-AllowedToDelegateTo=@("MSSQLSvc/ServerC.domain.com:1433", "MSSQLSvc/ServerC:1433")}
```

**Option 2 – GUI:**

* [ ] Open **Active Directory Users and Computers (ADUC)**
* [ ] Right-click `SQLB_SVC` → **Properties** → **Delegation** tab
* [ ] Select: ✅ *"Trust this user for delegation to specified services only"* + ✅ *"Use Kerberos only"*
* [ ] Click **Add...** → Select **ServerC**
* [ ] Choose both `MSSQLSvc/ServerC.domain.com:1433` and `MSSQLSvc/ServerC:1433`

---

### 🔹 **D. Validate Kerberos Authentication**

* [ ] Use `setspn -L DOMAIN\SQLB_SVC` to confirm SPNs
* [ ] Run a test SSIS package from ServerA
* [ ] From ServerB SQL Server, execute the linked server query to ServerC
* [ ] Check Event Viewer → Security log → for Kerberos ticket logs (`Event ID 4769`)
* [ ] Use `klist` on ServerA and ServerB to confirm Kerberos tickets

---

### 🔹 **E. Optional Mitigations / Alternatives**

* [ ] Consider **SQL Authentication** in the linked server (to avoid delegation)
* [ ] Redesign SSIS package to connect **directly from ServerA to ServerC**
* [ ] Disable **Credential Guard** (with security review) on:

  * ServerA and ServerB (to allow unconstrained delegation)
* [ ] Consider using **Project Deployment Model (SSISDB)** and **SQL Agent job on ServerB** (local execution, avoids double-hop)

---

