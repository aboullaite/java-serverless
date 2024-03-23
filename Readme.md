### Java & Serverless
This repo contains my java & Serverless demo for Google cloud Next 2024. 
This apps provide a chat endpoint that answers users question. Instead of only relying on its trained model, it also uses a RAG (Retrieval Augmented Generation) model to provide more accurate answers.
The additional knowledge is extracted from [java.dev](https://dev.java/learn/) website and aims to help java enthusiast to get started with Java programming.
The app is built using Spring boot, Vertex AI, Langchain4j, and deployed into Google Cloud run.

### Runtime optimizations:
The main focus of this repo is to compare defirent java app optimizations and check how they affect the (cold) startup time.
Below the results I got from running the app with @vCPUs, 2GB memory, [2nd Generation execution](https://cloud.google.com/run/docs/about-execution-environments) env with [CPU boost](https://cloud.google.com/run/docs/configuring/services/cpu#startup-boost) enabled.

| Optimization                                          | Cold start time |
|-------------------------------------------------------|-----------------|
| java 21 with no optimization                          | 10.301s         |
| java 21 with tiered compilation                       | 8.633s          |
| java 21 with Class data sharing (CDS)                 | 4.818s          |
| java 21 with CRaC (Coordinated Restore at Checkpoint) | 1.570s          |
| java 21 with Graal VM                                 | 0.911s          |

NB: The numbers are calculated based on the reported startup time from spring-boot logs.