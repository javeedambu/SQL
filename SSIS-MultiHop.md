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
