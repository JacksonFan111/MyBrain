# MyBrain
MyBrain-Knowledge Base for any thing that need to be Indexing
## Explored & annotated project structure (customized)
Below is a snapshot tailored to the folders shown in your workspace explorer. Edit descriptions as needed.

.
├── README.md                     # this file: project overview + structure
├── 00.Internal                   # internal configs, secrets (keep private), helpers
├── 01.DayToDayKnwoledge          # daily notes, personal knowledge, templates
├── 02.ProjectRelated             # active project folders, trackers, todos
├── 03.Learning                   # courses, notes, tutorials, study materials
├── 04.MyApps                     # your app projects, prototypes, microservices
├── 05.MyAgents                   # agent configs, automations, agent-related code
├── 06.DomainSpecificKnowledge    # specialized domain notes, corpora, datasets
├── 07.DayToDayOperations         # ops runbooks, scripts, cron jobs, infra
├── 08.OddStuff                   # experiments, hacks, scratchpad files
└── .devcontainer/                # devcontainer config for Ubuntu 24.04.2 LTS

Notes:
- Mark sensitive or private content under 00.Internal; do not commit secrets.
- Keep raw source data in a dedicated data/ folder if you add it.
- Use tests/ for unit/integration tests and docs/ for long-form guides.

To capture an exact machine snapshot, run this in the integrated terminal:
$ tree -a -I '.git|node_modules|__pycache__' -L 2

Replace or refine the short descriptions above to better match your intent for each folder.

