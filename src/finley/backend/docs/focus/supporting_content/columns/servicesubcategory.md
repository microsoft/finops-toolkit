# Column: ServiceSubcategory

## Example provider mappings

Current column mappings found in available data sets:

| Provider  | Data set                 | Column                                     |
| --------- | ------------------------ | ------------------------------------------ |
| AWS       | FOCUS; CUR                      | None                                       |
| GCP       | FOCUS; Big Query Billing Export | None                                       |
| Microsoft | FOCUS; Cost details             | None |
| OCI | FOCUS; Cost reports | None |

The creation of this publicly-available column shall be net-new for the cloud service providers, though they may already maintain their own proprietary Subcategories.  For example, AWS describes their Database Subcategories [here](https://docs.aws.amazon.com/whitepapers/latest/aws-overview/database.html).

## Discussion / Scratch space

### Principles

In addition to the principles as defined during the creation of Service Categories in FOCUS 0.5, the following principles shall also be followed when constructing Service Subcategories:

- Undercategorize rather than overcategorize where there is not broad consensus and/or materiality.
  - Allow the community to advocate for new Subcategories (and Categories) in future releases, and leave Services uncategorized and/or unsubcategorized in the meantime.
- Assign each Service to the one (and only one) Subcategory that describes its primary function.  
  - The Service hierarchy is meant to serve as a relatively high-level set of groupings that primarily address the needs of the Executive persona.  A given Service can fulfill multiple functions across and within organizations, and so the assignment of a Service to one and only one Category and Subcategory may be inaccurate from org to the next.  However, this hierarchy will then give the Practitioner a solid place to start, and they can make a few tweaks to its composition to meet their org's needs rather than create a hierarchy from scratch.  Ultimately, the creation and maintenance of the Service hierarchy requires us to embrace the imperfect and somewhat subjective nature of assigining a given Service to a single Category / Subcategory.
  - The (forthcoming) SKU hierarchy will be an opportunity to get very specific on the categorizations of cost and usage activity.  For example, GCP maintains a seven-level taxonomy for every SKU, and this will hopefully more concretely address the lower-level reporting needs of the Engineering persona.
  - Use the "Platforms" suffix whenever a subcategory is needed to cover products and services that span multiple other subcategories.
  - Avoid a "Platforms" subcategory if the service category does not have other subcategories.

### Sample provider mappings
Here are sample subcategorizations of various services across the AWS, Azure, and GCP landscape.

To be clear, this list is neither exhaustive nor prescriptive nor suggestive; it shall be up to the providers to decide where to assign their services, and FOCUS shall merely provide the list of available Subcategories.  This list was generated merely for illustrative purposes when constructing the subcategories.

| Service Category          | Service Subcategory                   | AWS                                                                       | Azure                                                                                                                 | GCP                                                                |
| ------------------------- | ------------------------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| AI and Machine Learning   | AI Platforms                          |                                                                           | AI Services, Video Indexer, Autonomous Systems, Syntex, Intelligent Recommendations                                   |                                                                    |
| AI and Machine Learning   | Bots                                  | Lex, Robomaker                                                            | Bot Service, Health Bot                                                                                               |                                                                    |
| AI and Machine Learning   | Generative AI                         | Bedrock, Q                                                                |                                                                                                                       | Gemini, Vertex AI                                                  |
| AI and Machine Learning   | Machine Learning                      | Sagemaker, Sagemaker Savings Plan, Lookout, Personalize                   | Machine Learning                                                                                                      |                                                                    |
| AI and Machine Learning   | Natural Language Processing           | Polly, Transcribe, Translate, Lex                                         |                                                                                                                       | natural language AI, text-to-speech, Speech-to-text, Document AI   |
| AI and Machine Learning   | Other (AI and Machine Learning)       | Capacity Blocks, Rekognition                                              |                                                                                                                       |                                                                    |
| Analytics                 | Analytics Platforms                   | Athena                                                                    | Fabric, Synapse, Data Explorer, Modeling and Simulation Workbench, Data Manager for Energy, Health Data Services      |                                                                    |
| Analytics                 | Business Intelligence                 | QuickSight                                                                | Power BI, Analysis Services, Grafana                                                                                  | Looker                                                             |
| Analytics                 | Data Processing                       | EMR, Batch, Glue, Data Pipeline                                           | Databricks, HDInsight, Data Lake Analytics, Analysis Services, Data Catalog, Genomics                                 | Cloud Composer, Dataflow, Dataproc                                 |
| Analytics                 | Search                                | Cognitive Search, CloudSearch, Elasticsearch, Kendra                      | Azure AI Search                                                                                                       | Vertex AI Search                                                   |
| Analytics                 | Streaming Analytics                   | Kinesis                                                                   | Stream Analytics                                                                                                      |                                                                    |
| Analytics                 | Other (Analytics)                     | Clean Rooms                                                               |                                                                                                                       |                                                                    |
| Business Applications     | Productivity and Collaboration        | WorkDocs, WorkLink, WorkMail, Chime                                       | Microsoft 365, Teams, Power Platform                                                                                  | Workspace                                                          |
| Business Applications     | Other (Business Applications)         | Supply Chain, Connect                                                     | Dynamics 365, Community Training                                                                                      |                                                                    |
| Compute                   | Containers                            | EKS, ECS                                                                  | AKS, Container Apps, Container Instances, Container Registry, Container Service, Service Fabric                       | GKE, Cloud Run                                                     |
| Compute                   | End User Computing                    | AppStream                                                                 | Virtual Desktop, Lab Services, Citrix                                                                                 |                                                                    |
| Compute                   | Quantum Compute                       | Braket                                                                    | Quantum                                                                                                               |                                                                    |
| Compute                   | Serverless Compute                    | Lambda                                                                    | Cloud Services, Batch                                                                                                 | Cloud Functions, Cloud Run                                         |
| Compute                   | Virtual Machines                      | EC2                                                                       | BareMetal Infrastructure, Dedicated Host, VMware Solution, SAP on Azure, Virtual Machine Scale Sets, Virtual Machines | Compute Engine                                                     |
| Compute                   | Other (Compute)                       | Compute Savings Plan                                                      | Savings Plan for Compute                                                                                              | Flex CUDs                                                          |
| Databases                 | Caching                               | ElastiCache, MemoryDB                                                     | Cache for Redis                                                                                                       | Memorystore                                                        |
| Databases                 | Data Warehouses                       | Redshift                                                                  | (none)                                                                                                                | BigQuery                                                           |
| Databases                 | Ledger Databases                      | QLDB, Managed Blockchain                                                  | Confidential Ledger                                                                                                   | Blockchain Node Engine                                             |
| Databases                 | NoSQL Databases                       | DynamoDB, Neptune, Cassandra, SimpleDB, AppSync                           | Cosmos DB                                                                                                             | Datastore, Bigtable, Firestore                                     |
| Databases                 | Relational Databases                  | RDS, Aurora                                                               | MariaDB, MySQL, PostgreSQL, SQL Database                                                                              | Cloud SQL, AlloyDB, Spanner                                        |
| Databases                 | Time Series Databases                 | Timestream                                                                | (none)                                                                                                                |                                                                    |
| Databases                 | Other (Databases)                     | Cloud Directory                                                           | (none)                                                                                                                |                                                                    |
| Developer Tools           | Developer Platforms                   | CodeCatalyst                                                              | DevOps, GitHub, App Center                                                                                            |                                                                    |
| Developer Tools           | Continuous Integration and Deployment | CodeDeploy, CodePipeline, CodeBuild, CodeArtifact                         |                                                                                                                       | Cloud Build, Cloud Deploy                                          |
| Developer Tools           | Development Environments              |                                                                           | Trusted Signing, Dev Box, Managed DevOps Pools                                                                        | Cloud Code                                                         |
| Developer Tools           | Source Code Management                | CodeCommit                                                                |                                                                                                                       |                                                                    |
| Developer Tools           | Quality Assurance                     | CodeGuru                                                                  | Playwright Testing, Load Testing, Test Base for M365                                                                  |                                                                    |
| Developer Tools           | Other (Developer Tools)               | re:Post Private                                                           |                                                                                                                       |                                                                    |
| Identity                  | Identity and Access Management        | IAM                                                                       | Entra ID, External Identities, Domain Services                                                                        | Cloud Identity, IAM                                                |
| Identity                  | Other (Identity)                      |                                                                           |                                                                                                                       |                                                                    |
| Integration               | API Management                        | API Gateway                                                               | API Center, API Management, Microsoft Graph                                                                           |                                                                    |
| Integration               | Messaging                             | SQS, SNS, EventBridge, Pinpoint                                           | Service Bus, Relay, Event Grid, Communcation Services, Notification Hubs                                              | Cloud Pub/Sub, Firebase                                            |
| Integration               | Workflow Orchestration                | Managed Workflows, Entity Resolution                                      | Apache Airflow, Data Factory, Logic Apps, Automation                                                                  |                                                                    |
| Integration               | Other (Integration)                   |                                                                           |                                                                                                                       |                                                                    |
| Internet of Things        | IoT Analytics                         |                                                                           | Digital Twins, Time Series Insights, FarmBeats                                                                        |                                                                    |
| Internet of Things        | IoT Platforms                         | IoT Core, Greengrass                                                      | IoT Central, IoT Hub, Windows for IoT, Defender for IoT                                                               |                                                                    |
| Internet of Things        | Other (Internet of Things)            |                                                                           |                                                                                                                       |                                                                    |
| Management and Governance | Architecture                          | Well-Architected Tool, Config, Trusted Advisor                            | (none)                                                                                                                |                                                                    |
| Management and Governance | Compliance                            | Compliance                                                                | Policy                                                                                                                |                                                                    |
| Management and Governance | Cost Management                       | Cost Explorer, Billing Conductor                                          | Reservations                                                                                                          | Invoice                                                            |
| Management and Governance | Data Governance                       | DataZone                                                                  | Purview                                                                                                               | Dataplex                                                           |
| Management and Governance | Disaster Recovery                     | DRS (Disaster Recovery Service)                                           | Chaos Studio, Site Recovery                                                                                           |                                                                    |
| Management and Governance | Endpoint Management                   |                                                                           | Intune, Universal Print, Defender for Endpoint                                                                        |                                                                    |
| Management and Governance | Observability                         | CloudWatch, CloudTrail, X-Ray, Grafana                                    | Monitor                                                                                                               | Cloud Monitoring, Cloud Logging, Cloud Trace                       |
| Management and Governance | Support                               | AWS Support                                                               | Support                                                                                                               | Customer Care ([Support](https://cloud.google.com/support/?hl=en)) |
| Management and Governance | Other (Management and Governance)     |                                                                           |                                                                                                                       |                                                                    |
| Media                     | Content Creation                      | Deadline                                                                  |                                                                                                                       |                                                                    |
| Media                     | Gaming                                |                                                                           | PlayFab                                                                                                               |                                                                    |
| Media                     | Media Streaming                       |                                                                           | Media Services                                                                                                        |                                                                    |
| Media                     | Mixed Reality                         |                                                                           | Spatial Anchors, Object Anchors, Remote Rendering                                                                     |                                                                    |
| Media                     | Other (Media)                         | Deadline                                                                  |                                                                                                                       |                                                                    |
| Migration                 | Data Migration                        | Database Migration, Snowball, Import/Export                               | Database Migration Service, Data Box, Import/Export, Data Share, File Sync                                            |                                                                    |
| Migration                 | Resource Migration                    | App Migration                                                             | Migrate                                                                                                               |                                                                    |
| Migration                 | Other (Migration)                     |                                                                           |                                                                                                                       |                                                                    |
| Mobile                    | Other (Mobile)                        |                                                                           |                                                                                                                       |                                                                    |
| Multicloud                | Multicloud Integration                |                                                                           | Arc, Stack Edge, Stack HCI                                                                                            |                                                                    |
| Multicloud                | Other (Multicloud)                    | Outposts                                                                  |                                                                                                                       | Anthos, AlloyDB Omni                                               |
| Networking                | Application Networking                | ELB, Application Load Balancer                                            | Load Balancer, Application Gateway, Traffic Manager                                                                   |                                                                    |
| Networking                | Content Delivery                      | CloudFront                                                                | Front Door, CDN                                                                                                       |                                                                    |
| Networking                | Network Connectivity                  | Ground Station, VPN Gateway, PrivateLink, Network Connect                 | Peering, 5G Core, Orbital, VPN Gateway, NAT Gateway, PrivateLink, Virtual WAN                                         | Cloud VPN, Cloud Interconnect                                      |
| Networking                | Network Infrastructure                | VPC, VPC Flow Logs                                                        | Virtual Network, Network Watcher, Network Function Manager                                                            | Shared VPC (XPN)                                                   |
| Networking                | Network Routing                       | Route 53                                                                  | ExpressRoute, DNS                                                                                                     |                                                                    |
| Networking                | Network Security                      | Web Application Firewall                                                  | Firewall, DDoS Protection, Bastion                                                                                    |                                                                    |
| Networking                | Other (Networking)                    |                                                                           |                                                                                                                       | Networking                                                         |
| Security                  | Secret Management                     | Secrets Manager, Certificate Manager, KMS, CloudHSM, Payment Cryptography | Key Vault, Dedicated HSM                                                                                              | Secret Manager, Certificate Authority, KMS                         |
| Security                  | Security Posture Management           | Security Hub, Macie                                                       | Defender for Cloud, Copilot for Security                                                                              |                                                                    |
| Security                  | Threat Detection and Response         | GuardDuty, Inspector, Detective, Shield, Security Lake                    | Dynamics 365 Fraud Protection                                                                                         |                                                                    |
| Security                  | Other (Security)                      |                                                                           |                                                                                                                       |                                                                    |
| Storage                   | Backup Storage                        | Backup                                                                    | Backup                                                                                                                |                                                                    |
| Storage                   | Block Storage                         | EBS                                                                       | Managed disk, ElasticSAN                                                                                              | Persistent Disks, Local SSDs                                       |
| Storage                   | File Storage                          | EFS                                                                       | NetApp Files                                                                                                          | Hyperdisk                                                          |
| Storage                   | Object Storage                        | S3, Glacier                                                               | ADLS                                                                                                                  | Cloud Storage                                                      |
| Storage                   | Storage Platforms                     |                                                                           | Storage Accounts, HPC Cache, StoreSimple                                                                              |                                                                    |
| Storage                   | Other (Storage)                       |                                                                           |                                                                                                                       |                                                                    |
| Web                       | Application Platforms                 | Elastic Beanstalk                                                         | App Service, Spring Apps                                                                                              | App Engine                                                         |
| Web                       | Other (Web)                           | Lightsail                                                                 | App Configuration, Maps, SignalR Service, Fluid Relay                                                                 | Maps {Directions API, Distance Matrix API, Geolocation API, etc.}  |
| Other                     | Other (Other)                         |                                                                           |                                                                                                                       |

### Discussion Outcomes

A series of open questions were discussed over the course of July and August 2024, both in the [draft spreadsheet](https://docs.google.com/spreadsheets/d/1aYq79sWp8TK4zbcSKUb-gRIBei3fERVwAgDJ5ezZf1w/edit?usp=sharing) and in Task Force (TF) and Member calls.  This section attempts to describe the largest topics and outcomes of those discussions.

#### Shall the Category composition change from FOCUS 1.0?

With Subcategories now in scope for FOCUS 1.1, there was then the potential of changing Categories.  For example: 

- `Identity` could become a child Subcategory of `Security`.
- `Web` and `Mobile` could be grouped together into a net-new category (proposed `Front-end` or `Application Tools`).
- Activity that is truly cross-categorical could be placed in a net-new category (proposed `Crossfunctional`) separate from `Other`, which is more of an uncategorized placeholder.
- `Integration` could be rescoped and renamed `Data Management` to be more inclusive of Service Subcategories such as Data Processing and API Management.
- `Multicloud` could be rescoped and renamed `Hybrid and Multicloud` to be more inclusive of on-premises Services.

After much discussion, particularly on the Aug 6 TF1 call, it became clear that the "burden of proof" for changing existing Categories is higher, given that some of the group feels this to constitute a "breaking change".  Some of the group felt that the Service hierarchy should be considered more of a "living document" that is revisited from one FOCUS release to another, in order to stay more tightly aligned with the slowly-changing nature of Service categorizations; others felt that would be prohibitively disruptive for FOCUS consumers who have constructed various downstream artifacts and depend on a certain Category and Subcategory composition.

_Outcome_: leave the Category composition in place for FOCUS 1.1 and narrow scope of this release to only add Subcategories underneath them, leaving the door open to alter the Category composition in a future release (either major or not, pending a larger decision around what constitutes a "breaking change").

#### Shall the Subcategory (and Category) assignment describe the activity's _use case_?

Consider the example of [AWS Inf2 VM instances](https://aws.amazon.com/ec2/instance-types/inf2/).  These instance types are purpose-built to be used for AI and ML use cases, and so any related cost and usage activity belongs in the Category of `AI and Machine Learning`, right?

Not so fast.  While the _intended purpose_ of this VM is for AI use cases, it's still a VM that technically could be used for anything.  Ultimately, we cannot attempt to categorize the _SKU_ with our Service Subcategory; we can only categorize the Service, which in this case is still EC2, which therefore falls into `Compute > Virtual Machines`.  When FOCUS implements a SKU taxonomy / hierarchy, we would be able to get more specific about the use of Inf2 vs, say, T2 instances.  Any reporting that attempted to better convey the use case would either need to leverage that future hierarchy or an appropriate tag of the involved Resources that conveys purpose.

This was discussed at the Jul 30 TF1 call, and the strong majority, if not consensus, opinion was that examples such as these should remain in their Service's assignment, regardless of use case.  However, it does not dismiss the fair point that a Service Category of AI & Machine Learning will exclude Services that can be used for AI and ML purposes.  That is an issue that goes beyond the scope of these columns and must be solved with other mechanisms.

_Outcome_: Service Category and Subcategory shall describe the Service's primary function -- not the use case of the usage or SKU.

#### Where do Commitment Discounts belong?

Commitment Discounts have various models that could belong in various places of a Service category hierarchy.  For example:

- An Azure reservation for D8as v5 can be both Categorized (i.e. `Compute`) and Subcategorized (i.e. `Virtual Machines`).
- An AWS Compute savings plan can be Categorized (i.e. `Compute`) but not Subcategorized (e.g. it can be applied to both `Virtual Machines` and `Serverless Compute`).
- An OCI Credit can neither be Categorized nor Subcategorized (e.g. it can be applied to a wide variety of usage).

Based on that, there was a robust discussion, particularly on the Jul 23 TF1 and Aug 8 Member calls, as to where Commitment Discounts belong.  Do they deserve their own Subcategories (e.g. `Commitments (Compute)`, `Commitments (Databases)`) underneath each Category?  Do they also deserve their own Category (e.g. `Commitments` or `Crossfunctional`)?

_Outcome_: given the decision not to change the Category composition, and given the principle of undercategorizing rather than overcategorizing: 

- Commitment Discounts with a natural Category / Subcategory shall be placed therein.
- Commitment Discounts with a natural Category but no Subcategory shall be placed in `Other (<Category>)`.
- Commitment Discounts with no natural Category or Subcategory shall be placed in `Other (Other)`.

#### Shall certain technologies be given their own Categories?

The group discussed the possibility of "graduating" Services to their own net-new categories, such as `Blockchain`, `Containers`, and `Mixed Reality`.  These are technologies for which some or all of the three major cloud service providers have created their own Categories, and there is certainly a use case for being able to easily build reports to show those (and only those) Services.

Given the decision not to change the Category composition on the Aug 6 TF1 call, this became a moot discussion.  However, the group did discuss some specific examples, particularly on the Jul 23 TF1 and Jul 25 Member calls:

- `Blockchain` belongs under `Databases > Ledger`.
- `Containers` belongs under `Compute > Containers`.
- `Support` belongs under `Management and Governance`.
- `Mixed Reality` does not deserve its own Category.
- `Industry Specific` does not deserve its own Category.
- `Marketplace` Services shall be placed into the Category and Subcategory aligned with their purpose, rather than placed into a `Marketplace` Category.

_Outcome_: No Category additions or changes at this time.

#### What shall we call the "unsubcategorized" Subcategory?

Each Category carries an "Other" Subcategory to allow the providers to provide a Category without a Subcategory.  A vote was issued via Slack on Aug 13 with the following options:

:one: `Uncategorized (<Category Name>)`  
:two: `Other (<Category Name>)`  
:three: `Uncategorized`  
:four: `Other`  

The following considerations were included:

- Brevity, simplicity, and consistency of Subcategory names (e.g. “Uncategorized (Management and Governance)” is pretty long).
- Delineation of Category values from Subcategory values (e.g. use of Subcategory “Other” underneath all Categories “Compute”, “Databases” and “Other” could be confusing).
- Analytical utility of Subcategory without Category context (e.g. uncategorized Compute from uncategorized Databases are automatically separated in a bar chart).

_Outcome_: Option :two: was chosen.

#### Why do some of the Categories lack Subcategories beyond "Other"?

Per the principles and some of the outcomes described above, we have leaned towards subcategorizing only those Categories on which we had broad consensus and/or could target significant usage.  Several of the existing Categories do not have sufficient Service counts and/or activity to allow designating Subcategories at a high degree of confidence, and future FOCUS versions can add such groupings if and when requested by the community.

#### Shall this column be mandatory or optional?

There was some discussion around this at the 8/15 Member call.  Some felt that Service Subcategory should be mandatory because Service Category is mandatory, and together they form a hierarchy.  Others felt that provider adoption would be easier if the column were not required.  Still others felt that making the column mandatory, even populated completely with Other, would entice FOCUS consumers to petition their provider(s) to populate the column with actual Subcategories.

Ultimately, it seemed that the majority leaned towards making it optional.

_Outcome_: Optional.




