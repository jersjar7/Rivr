# Data Handling Procedures for Thesis Research (Under Development)
## IRB Compliance Documentation

**Research Project**: Accessible River Flow Notifications from NOAA National Water Model  
**Principal Investigator**: Jerson Garcia  
**Institution**: Brigham Young University  
**IRB Protocol**: [Protocol Number] TBD  
**Date**: Jun 10, 2026

## Overview

This document outlines comprehensive data handling procedures for thesis research compliance with Institutional Review Board (IRB) requirements and research ethics standards. All procedures prioritize participant privacy, data security, and research integrity.

## Data Classification

### Human Subjects Data
**Category**: Minimal Risk Research Data  
**Sensitivity Level**: Moderate (contains personal information but non-sensitive)  
**Regulatory Compliance**: IRB oversight, FERPA (if applicable), institutional policies

### Data Types Collected

#### Primary Data (Direct Collection)
1. **Demographics**: Age range, experience level, general location
2. **Contact Information**: Email addresses for study communication
3. **Interview Data**: Audio recordings and transcripts
4. **Survey Responses**: Questionnaire and assessment responses
5. **Observational Data**: Usability testing notes and observations

#### Secondary Data (System Generated)
1. **Usage Analytics**: App interaction patterns and frequency
2. **Notification Data**: Delivery, open rates, and user responses
3. **Configuration Data**: User-set thresholds and preferences
4. **System Logs**: Technical performance and error data

## Data Collection Procedures

### Pre-Collection Requirements
- **IRB Approval**: Confirmed approval before any data collection
- **Informed Consent**: Signed consent forms from all participants
- **Privacy Training**: Research team trained on privacy procedures
- **System Security**: Technical safeguards verified and tested

### Collection Methods

#### Interview Data Collection
**Procedure**:
1. Obtain explicit verbal consent for recording
2. Use university-approved recording equipment
3. Create immediate backup of recordings
4. Assign anonymous participant IDs
5. Store recordings on encrypted, university-managed systems

**Data Elements**:
- Audio recordings (temporary)
- Transcription files (anonymized)
- Interview notes (anonymized)
- Participant metadata (separate from content)

#### Digital Usage Data Collection
**Procedure**:
1. Configure Firebase Analytics with privacy settings
2. Implement data minimization (collect only necessary data)
3. Use hashed user identifiers (no personal information)
4. Set automatic data retention limits
5. Document all data collection points in app

**Data Elements**:
- Screen interactions and navigation patterns
- Notification delivery and engagement metrics
- Feature usage frequency and duration
- User-configured settings and preferences

#### Survey and Assessment Data
**Procedure**:
1. Use secure, university-approved survey platforms
2. Assign anonymous participant IDs
3. Export data to secure research systems
4. Verify data integrity and completeness
5. Remove any accidentally collected personal information

## Data Storage and Security

### Physical Security
- **Location**: University-managed, secure facilities
- **Access Control**: Keycard/badge access to research areas
- **Equipment Security**: Locked offices and secured workstations
- **Backup Storage**: Secure, off-site university backup systems

### Digital Security Measures

#### Encryption Standards
- **Data in Transit**: TLS 1.3 or higher for all data transmission
- **Data at Rest**: AES-256 encryption for stored research data
- **Database Security**: Encrypted Firebase Firestore with access controls
- **File Storage**: University-provided encrypted cloud storage

#### Access Controls
- **Principle of Least Privilege**: Minimum necessary access for each team member
- **Multi-Factor Authentication**: Required for all research system access
- **Regular Access Reviews**: Quarterly review of access permissions
- **Automatic Lockouts**: Session timeouts and failed login protections

#### Network Security
- **University Networks**: Use of institutional secure networks
- **VPN Requirements**: VPN access for remote research work
- **Firewall Protection**: University-managed network security
- **Regular Updates**: Prompt application of security patches

### Data Organization

#### File Naming Conventions
```
Format: [PROJECT]_[DATATYPE]_[PARTICIPANT_ID]_[DATE]
Examples:
- RIVR_INTERVIEW_P001_20240610
- RIVR_USAGE_P001_20240610
- RIVR_SURVEY_P001_20240610
```

#### Directory Structure
```
/secure_research_drive/rivr_thesis/
├── /raw_data/
│   ├── /interviews/
│   ├── /surveys/
│   ├── /usage_analytics/
│   └── /system_logs/
├── /processed_data/
│   ├── /anonymized/
│   ├── /aggregated/
│   └── /analysis_ready/
├── /documentation/
└── /backups/
```

## Data Processing and Analysis

### Anonymization Procedures

#### Immediate Anonymization
1. **ID Assignment**: Replace names with anonymous participant IDs
2. **Location Generalization**: Use regional identifiers instead of specific locations
3. **Date Generalization**: Use relative timeframes where possible
4. **Demographic Binning**: Use age ranges instead of specific ages

#### Content Anonymization
1. **Interview Transcripts**: Remove or mask identifying information
2. **Usage Data**: Hash device identifiers and user tokens
3. **Survey Responses**: Strip metadata containing personal information
4. **System Logs**: Remove IP addresses and device-specific identifiers

### Data Validation
- **Completeness Checks**: Verify all required data elements collected
- **Accuracy Verification**: Cross-check data against source systems
- **Consistency Validation**: Ensure data integrity across collection points
- **Anomaly Detection**: Identify and investigate unusual data patterns

### Analysis Security
- **Secure Workstations**: University-managed computers for data analysis
- **Software Licensing**: Use institutionally licensed analysis software
- **Version Control**: Track all analysis scripts and procedures
- **Reproducibility**: Document all analysis steps and decisions

## Data Sharing and Collaboration

### Internal Sharing (Research Team)
**Authorized Personnel**:
- Principal Investigator (full access)
- Research Supervisor (full access)
- Graduate Research Assistant (limited access as needed)

**Sharing Procedures**:
- Use university-approved file sharing systems
- Maintain access logs for all data transfers
- Require signed confidentiality agreements
- Regular training on data handling procedures

### External Sharing (Not Permitted)
- No sharing with external researchers during active study
- No commercial use of research data
- No sharing of individual participant data
- Future academic collaboration requires separate IRB approval

## Data Retention and Disposal

### Retention Schedule

#### During Active Research (Months 1-8)
- **Raw Data**: Maintained on secure systems with regular backups
- **Working Files**: Daily backups and version control
- **Personal Identifiers**: Minimal retention, immediate anonymization when possible

#### Post-Study Period (Months 9-12)
- **Audio Recordings**: Deleted within 30 days of thesis completion
- **Personal Identifiers**: Deleted within 60 days of thesis completion
- **Anonymized Data**: Retained for potential academic publication
- **Aggregated Results**: Retained indefinitely for research record

#### Long-term Retention (Year 2+)
- **Anonymized Datasets**: Potential retention for follow-up research
- **Analysis Scripts**: Retained for reproducibility
- **Research Documentation**: Permanent retention per university policy

### Secure Disposal Procedures
- **Physical Media**: Professional shredding or degaussing
- **Digital Files**: Cryptographic wiping with verification
- **Cloud Storage**: Secure deletion with provider confirmation
- **Documentation**: Maintain disposal records per IRB requirements

## Incident Response Procedures

### Data Breach Response
1. **Immediate Containment**: Isolate affected systems
2. **Assessment**: Determine scope and nature of breach
3. **Notification**: IRB and university security within 24 hours
4. **Documentation**: Complete incident report
5. **Participant Notification**: If personal data potentially exposed
6. **Remediation**: Implement corrective measures

### Technical Failure Response
1. **System Recovery**: Activate backup and recovery procedures
2. **Data Integrity Check**: Verify no data loss or corruption
3. **Timeline Assessment**: Evaluate impact on research schedule
4. **Stakeholder Communication**: Notify supervisor and IRB if significant
5. **Process Review**: Analyze and improve procedures

## Quality Assurance

### Regular Audits
- **Monthly Security Reviews**: Verify access controls and security measures
- **Quarterly Data Audits**: Check data integrity and handling compliance
- **Annual Procedure Review**: Update procedures based on lessons learned

### Training and Certification
- **Initial Training**: All team members complete IRB training
- **Privacy Training**: Specific training on data handling procedures
- **Annual Refreshers**: Updated training on new requirements
- **Competency Verification**: Regular assessment of procedure knowledge

### Documentation Requirements
- **Procedure Updates**: Document all changes to data handling procedures
- **Access Logs**: Maintain records of all data access and modifications
- **Training Records**: Document completion of required training
- **Audit Trails**: Comprehensive logging of all data-related activities

## Compliance Monitoring

### IRB Reporting
- **Progress Reports**: Regular updates to IRB on study progress
- **Adverse Events**: Immediate reporting of any privacy or security incidents
- **Protocol Modifications**: IRB approval for any procedure changes
- **Final Reports**: Comprehensive study completion report

### University Policy Compliance
- **Information Security**: Adherence to institutional security policies
- **Research Data Management**: Compliance with university data policies
- **Records Retention**: Following institutional retention schedules
- **Risk Management**: Regular assessment and mitigation of data risks

## Contact Information for Compliance

### Primary Contacts
**Principal Investigator**: Jerson Garcia - jerson01@byu.edu - (385) 201-8283  
**Research Supervisor**: Dr. Dan Ames - dan.ames@byu.edu    
**IRB Office**: [IRB Contact] - [Email] - [Phone] TBD  

### Emergency Contacts
**University IT Security**: [Security Contact] - [Email] - [Phone]  TBD  
**Research Compliance Office**: [Compliance Contact] - [Email] - [Phone] TBD  
**Data Protection Officer**: [DPO Contact] - [Email] - [Phone] TBD

---

**Document Version**: 1.0  
**Last Review**: Jun 10, 2025  
**Next Review**: [Date + 6 months]  
**Approved By**: [IRB Chair/Research Supervisor] TBD

*This document is a living document and will be updated as procedures evolve or requirements change.*
