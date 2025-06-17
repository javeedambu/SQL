Certainly! Here’s a fully revised and consolidated **technical discussion document** based on your updated input, including Rubrik backup, the absence of VM-level backup, and the four proposed SQL Server architecture options.

---

# **BizTalk Database Architecture Options – Parallel Build Migration**

## **1. Project Background**

This document outlines proposed database architecture options for the **parallel build migration** of the BizTalk environment. The goal is to migrate from a legacy platform to a supported and sustainable infrastructure while maintaining or improving availability, manageability, and disaster recovery (DR) capabilities.

---

## **2. Current Environment Overview**

| Component                   | Details                                                   |
| --------------------------- | --------------------------------------------------------- |
| OS Version                  | Windows Server 2012 R2                                    |
| BizTalk Server              | BizTalk 2016                                              |
| SQL Server                  | SQL Server 2016 Standard                                  |
| SQL HA Setup                | Windows Server Failover Clustering (WSFC)                 |
| Number of BizTalk Databases | 5 databases                                               |
| Backup Strategy             | **Rubrik** for database backups only (no VM-level backup) |
| VM Protection               | **No VMware-based backup**                                |
| Witness Configuration       | Shared folder on NAS                                      |

---

## **3. Target Environment Overview**

| Component            | Details                                         |
| -------------------- | ----------------------------------------------- |
| OS Version           | Windows Server 2022                             |
| BizTalk Server       | BizTalk 2020                                    |
| SQL Server           | SQL Server 2022 Standard                        |
| Proposed HA Strategy | Under Evaluation                                |
| Backup Strategy      | Continued use of **Rubrik** for DB backups      |
| VM Provisioning      | VMs must be rebuilt manually in case of failure |

---

## **4. Evaluation Criteria**

* **High Availability (HA)** and **Disaster Recovery (DR)**
* **Licensing and Cost Impact**
* **Operational Complexity**
* **Recovery Time Objective (RTO)**
* **BizTalk Compatibility**
* **Infrastructure Dependencies**

---

## **5. Options Analysis**

### **Option 1: Single SQL Server (No HA, No Standby)**

#### Description:

A single SQL Server VM runs all BizTalk databases without clustering or standby.

#### Recovery Process:

* In case of VM failure: Request new VM → Install OS and SQL Server → Restore databases from **Rubrik**.
* **No automated recovery. Longest RTO.**

#### ✅ Pros:

* Lowest cost and licensing
* Simplest setup and management

#### ❌ Cons:

* **Single point of failure**
* **No HA or DR capabilities**
* Full VM rebuild needed during outage
* Not suitable for production workloads

#### 🔄 RTO Estimate:

* **High** (several hours to a full day)

#### 💰 Licensing:

* One SQL Server 2022 Standard license

---

### **Option 2: Single SQL Server with Cold Standby VM**

#### Description:

Primary SQL Server runs all databases. A second VM with SQL installed is **prebuilt and idle**, used only during catastrophic failure of primary.

#### Recovery Process:

* Activate standby VM → Restore databases from **Rubrik**
* No need to request/build a new VM

#### ✅ Pros:

* Improved RTO vs Option 1
* Standby VM reduces outage duration
* No data replication, simple to operate
* Cost-effective if SA licensing used correctly

#### ❌ Cons:

* Still **manual failover and restore**
* No real-time synchronization
* Some data loss (depends on last Rubrik backup)

#### 🔄 RTO Estimate:

* **Medium** (2–4 hours)

#### 💰 Licensing:

* One SQL Server license (standby allowed under Software Assurance)
* No need to license standby unless activated long-term

---

### **Option 3: SQL Basic Availability Groups (AG)**

#### Description:

Two SQL Server Standard Edition VMs, configured with **Basic Availability Groups**, each hosting **one database per AG**. Connectivity managed via **DNS CNAME** pointing to active node.

#### Recovery Process:

* Automatic database failover (AG), but requires **manual DNS CNAME update**
* No VM rebuild necessary

#### ✅ Pros:

* **Real-time HA** for each database
* No shared storage required
* Better RTO than Option 2
* Reduces need for Rubrik-based restores

#### ❌ Cons:

* Manual DNS redirection required after failover
* Requires **SQL licensing for both servers**
* **Limited to 1 DB per AG** (Standard Edition constraint)
* BizTalk compatibility with AG + CNAME must be validated
* More monitoring and failover orchestration needed

#### 🔄 RTO Estimate:

* **Low** (15–30 minutes, depending on DNS management)

#### 💰 Licensing:

* Two SQL Server 2022 Standard licenses
* Additional DNS or failover orchestration tools may help

---

### **Option 4: Windows Server Failover Cluster (WSFC) – Like-for-Like**

#### Description:

Maintain current WSFC setup with two SQL VMs in an **active-passive** failover cluster using shared storage and NAS-based witness.

#### Recovery Process:

* **Automatic failover** handled by WSFC
* No need to rebuild VMs or restore from Rubrik (unless both nodes fail)

#### ✅ Pros:

* Fully automated failover
* Maintains BizTalk compatibility (proven model)
* Seamless client experience (no DNS updates)
* **Best RTO and HA**

#### ❌ Cons:

* Requires shared storage (NAS/SAN)
* More complex to deploy and maintain
* Requires two SQL Server licenses
* OS/SQL patching is more involved

#### 🔄 RTO Estimate:

* **Very Low** (Seconds to <2 minutes)

#### 💰 Licensing:

* Two SQL Server 2022 Standard licenses
* Cost for shared storage infrastructure

---

## **6. Comparative Summary Table**

| Option              | HA             | DR         | RTO         | Licensing  | Complexity     | Infra Needs                | BizTalk Compatibility |
| ------------------- | -------------- | ---------- | ----------- | ---------- | -------------- | -------------------------- | --------------------- |
| **1. Single SQL**   | ❌              | ❌          | 🔴 High     | 💲 Low     | 🟢 Low         | 🟢 Basic                   | ✅ Supported           |
| **2. Cold Standby** | ❌              | ✅ (Manual) | 🟠 Medium   | 💲 Low–Med | 🟠 Medium      | 🟢 Basic + 1 standby       | ✅ Supported           |
| **3. Basic AG**     | ✅ (Manual DNS) | ✅          | 🟢 Low      | 💲💲 High  | 🟠 Medium–High | 🟢 No shared storage       | ⚠️ Needs testing      |
| **4. WSFC**         | ✅ (Auto)       | ✅          | 🟢 Very Low | 💲💲 High  | 🔴 High        | 🔴 Shared storage, witness | ✅ Proven model        |

---

## **7. Recommendations**

| Priority               | If You Want…                                    | Recommended Option          |
| ---------------------- | ----------------------------------------------- | --------------------------- |
| 🥇 Best HA & RTO       | Minimal downtime, proven compatibility          | **Option 4 – WSFC**         |
| 🥈 Balanced Cost vs DR | Reasonable restore time without high infra cost | **Option 2 – Cold Standby** |
| 🥉 Cost-effective HA   | Real-time HA with some operational overhead     | **Option 3 – Basic AG**     |
| 🟥 Cost-only Focus     | Accept high risk and long recovery time         | **Option 1 – Single SQL**   |

---

## **8. Next Steps**

* Confirm BizTalk 2020 compatibility with Basic AG and DNS CNAME model
* Evaluate availability of shared storage for WSFC
* Define RTO and RPO thresholds for the production environment
* Consider automation tools for DNS failover (if Option 3 is pursued)
* Verify Rubrik restore SLAs and testing for VM rebuild procedures

---

Would you like this packaged in:

* 📄 **Word/PDF document** with visual diagrams and summary charts?
* 🖥️ **PowerPoint deck** for stakeholder presentation?
* 🧾 Markdown or Confluence-style page for internal documentation?

Let me know your preferred format!
