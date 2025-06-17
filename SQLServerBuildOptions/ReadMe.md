---

# **SQL Server HA Design Evaluation for BizTalk 2020 Migration**

## **1. Purpose**

This document evaluates options for SQL Server high availability (HA) in the upcoming migration from BizTalk Server 2016 (on SQL 2016 and Windows 2012 R2) to **BizTalk Server 2020 on SQL Server 2022 Standard and Windows Server 2022**.

We assess alternatives to the existing **WSFC-based setup** using technical, operational, and licensing perspectives.

---

## **2. Current Architecture (Source)**

| Component          | Detail                                   |
| ------------------ | ---------------------------------------- |
| BizTalk Version    | BizTalk Server 2016                      |
| SQL Server Version | SQL Server 2016 Standard                 |
| OS                 | Windows Server 2012 R2                   |
| SQL HA Model       | WSFC (Windows Server Failover Cluster)   |
| Cluster Quorum     | **File Share Witness** (no disk witness) |
| Shared Storage     | **RDM (Raw Device Mapping)** via VMware  |
| Backups            | Database-level backups via **Rubrik**    |
| VMware             | Fully redundant vSphere infra (HA + DRS) |
| VM Backups         | ❌ No image-level VM backups              |

---

## **3. Target Architecture (To-Be)**

| Component          | Detail                        |
| ------------------ | ----------------------------- |
| BizTalk Version    | BizTalk Server 2020           |
| SQL Server Version | SQL Server 2022 Standard      |
| OS                 | Windows Server 2022           |
| SQL HA Model       | **Under evaluation**          |
| Backups            | Rubrik (unchanged)            |
| VMware             | Redundant vSphere (unchanged) |

---

## **4. SQL HA Options Under Review**

The following SQL Server HA/DR design options are being considered for the target BizTalk 2020 environment:

| Options      | Description                                                                                                                   |
| ------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| **1** | **Single SQL Server** — One SQL VM only, no HA or DR configuration                                                            |
| **2** | **Single SQL Server + Cold Standby** — Standby VM prebuilt but inactive, used for manual recovery                             |
| **3** | **Basic Availability Groups (SQL Standard Edition)** — Two SQL VMs with per-database AGs and DNS-based failover               |
| **4** | **Windows Server Failover Cluster (WSFC)** — Two-node cluster using shared RDM storage and file share witness **(current model)** |


### ✅ **Option 1: Single SQL Server (No HA)**

One SQL VM running all BizTalk databases. No failover, cluster, or standby.

* OS crash = **full VM rebuild**, SQL install, Rubrik restore, DB consistency check
* VMware HA covers host failure only (VM restarts elsewhere)

**RTO**: 🔴 4–8 hours
**Data Redundancy**: ❌ None

**Pros**:

* Simplest setup
* Lowest licensing cost

**Cons**:

* Single point of failure
* Manual rebuild & validation
* Unacceptable for production in most orgs

---

### 🟠 **Option 2: Single SQL Server + Cold Standby**

Second SQL Server VM built and patched, but **not active**. Activated only during disaster.

* Failure = Promote standby → Restore from Rubrik → Run DBCC checks
* Faster recovery than Option 1 but **not automatic**

**RTO**: 🟠 2–4 hours
**Data Redundancy**: ❌ None (until restored)

**Pros**:

* Minimal infra cost beyond Option 1
* Quicker than full rebuild
* No shared disk or clustering needed

**Cons**:

* No automatic failover
* Requires manual restore + checks
* Data loss within last backup window

---

### 🟡 **Option 3: Basic Availability Groups (SQL Standard Edition)**

* Two SQL Server VMs with **Basic Always On AG**
* Each database in its own AG (SQL Std supports only 1 DB per AG)
* Uses **BizTalk DNS alias (CNAME)** pointing to primary SQL instance

**Failover Steps**: Fail AG manually → Update DNS alias to new primary → BizTalk reconnects

**RTO**: 🟢 15–30 minutes (manual DNS update)
**Data Redundancy**: ✅ Two full database copies

**Pros**:

* Real-time synchronization
* Built-in redundancy of data
* No shared storage required

**Cons**:

* Requires manual DNS repointing (no built-in listener support in SQL Std)
* Slight complexity due to per-DB AG setup
* Must validate BizTalk compatibility with CNAME failover

---

### 🟢 **Option 4: WSFC with RDM Shared Disk (Current Model)**

* Two-node WSFC cluster using **shared storage (RDM via VMware)**
* Witness is a **file share**, not a quorum disk
* BizTalk connects via instance name; failover is **fully transparent**

**RTO**: 🟢 <2 minutes (automatic failover)
**Data Redundancy**: ❌ No second copy (single shared disk)

**Pros**:

* Proven and familiar BizTalk HA model
* Automatic failover — seamless to applications
* No application logic change or DNS management

**Cons**:

* Only **one copy of data** (shared disk = single point of failure)
* Shared storage adds complexity (RDM mapping, zoning, etc.)
* Not cloud-friendly or flexible in modern deployments

---

## **5. Technical Comparison Table**

| Feature / Criteria        | Option 1<br>(Single) | Option 2<br>(+Standby) | Option 3<br>(Basic AG) | Option 4<br>(WSFC RDM) |
| ------------------------- | -------------------- | ---------------------- | ---------------------- | ---------------------- |
| HA / Failover Type        | ❌ None               | ❌ None                 | 🟡 Manual (DNS)        | ✅ Automatic            |
| Data Redundancy           | ❌ None               | ❌ None                 | ✅ Yes (2 copies)       | ❌ No (shared disk)     |
| Storage Dependency        | 🟢 None              | 🟢 None                | 🟢 Local disks         | 🔴 RDM Shared Disk     |
| Shared Storage Required   | ❌ No                 | ❌ No                   | ❌ No                   | ✅ Yes (RDM)            |
| Witness / Quorum          | N/A                  | N/A                    | N/A                    | ✅ File Share Witness   |
| Failover Complexity       | 🔴 Full rebuild      | 🟠 Manual restore      | 🟡 DNS update needed   | 🟢 Seamless            |
| VMware HA Coverage        | ✅ Yes                | ✅ Yes                  | ✅ Yes                  | ✅ Yes                  |
| Licensing Required        | 1 Std                | 1 Std (+DR rights)     | 2 Std                  | 2 Std                  |
| BizTalk Compatibility     | ✅ Yes                | ✅ Yes                  | ⚠️ Must test CNAME     | ✅ Fully Supported      |
| RTO (Real World)          | 🔴 4–8+ hrs          | 🟠 2–4 hrs             | 🟢 \~30 min            | 🟢 <2 min              |
| DBA Workload Post-Failure | 🔴 High              | 🟠 Medium              | 🟡 Low                 | 🟢 Low                 |

---

## **6. Recommendation Summary**

| Priority                     | Recommended Option          |
| ---------------------------- | --------------------------- |
| ✅ **Seamless BizTalk HA**    | **Option 4 – WSFC (RDM)**   |
| ✅ **Data redundancy needed** | **Option 3 – Basic AG**     |
| 💰 **Cost-aware DR only**    | **Option 2 – Cold Standby** |
| 🚫 **Non-prod / Dev only**   | **Option 1 – Single SQL**   |

---

## **7. Final Notes**

* **VMware HA/DRS** already ensures **automatic recovery from ESXi host failure**
* Failures like **OS corruption** still require **VM rebuild** and **DB validation**
* **Rubrik** is the backup/restore method — **DBCC checks are mandatory** post-recovery
* BizTalk 2020 must be validated to work with **DNS alias failover** (Option 3)
* WSFC still has a **single storage failure domain** due to shared RDM

---

## **8. Action Items**

| Task                                                   | Owner        | Status    |
| ------------------------------------------------------ | ------------ | --------- |
| Validate DNS alias-based failover with BizTalk 2020    | BizTalk Team | ⏳ Pending |
| Confirm licensing position for cold standby (Option 2) | Licensing/IT | ⏳ Pending |
| Review NAS/RDM storage redundancy                      | Infra Team   | ⏳ Pending |
| Document Rubrik + DB consistency check SOP             | DBAs         | ⏳ Pending |
| Consider scripting DNS update for Option 3             | Infra/DevOps | ⏳ Pending |

---

Would you like this in:

* 📄 Word or PDF format for sharing?
* 📊 PowerPoint summary for stakeholder presentation?
* 📝 Markdown or Confluence format?

Let me know and I’ll generate it!
