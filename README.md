# Fullstack AI App

This repository contains a minimal full-stack scaffold:
- React (Vite + TypeScript) frontend
- FastAPI (Python) backend
- Mixed data layer: Postgres (SQL) + MongoDB (NoSQL)
- GenAI integration via an OpenAI-compatible API
- Docker Compose for local development

## Quick start

1. Optional: copy `.env` and set your `OPENAI_API_KEY` to enable real AI replies.
2. Start services:

  - Using Docker Compose:
  ```sh
  docker compose up --build
  ```
  - Frontend: http://localhost:5173
  - Backend: http://localhost:8000/api/health

If you prefer running locally without Docker, see the sections below.
## Backend (FastAPI)

Path: `backend/`
Environment variables (see `.env`):

- `DATABASE_URL` (default points to docker Postgres)
- `MONGO_URL`, `MONGO_DB`
- `OPENAI_API_KEY`, `OPENAI_BASE_URL`, `OPENAI_MODEL`

Run locally:
```sh
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```
API endpoints:

- `GET /api/health` – health check
- `POST /api/users` – create user `{ name, email }`
- `GET /api/users` – list users
- `POST /api/chat?user_id=...&message=...` – send a prompt, stores messages in Postgres and a log in MongoDB

## Frontend (React)

Path: `frontend/`
Run locally:

```sh
cd frontend
npm i
npm run dev
```
Configure the backend URL with `VITE_API_BASE_URL` (defaults to `http://localhost:8000`).

## Data layer

- Postgres stores users and chat messages (via SQLModel/SQLAlchemy)
- MongoDB stores simple usage logs

## Notes

- Without `OPENAI_API_KEY`, the backend returns a stubbed response for `/api/chat`.
- This scaffold is intended for development; harden for production (secrets, auth, migrations, indexes, rate limiting).

# fullstack
fullstack

# Structure

Got it — I'll continue in English from here.

Here’s a consolidated view of the tech stack for **Rakuten Agent Experience Department (AGEX)** based on available job postings and Rakuten engineering info:

---

## **Frontend Framework**

* Rakuten engineering teams commonly use **React** or **Angular**.
* While AGEX-specific postings don’t explicitly say "React" or "Angular," Rakuten’s Global Ad Division and other AI/agent-related teams mention them, so AGEX is very likely aligned with **React (primary)** or **Angular.js**.

---

## **Backend & Python Usage**

* **Python** is used for building backend services that power AI-driven applications.
* Typical stack includes:

  * **RESTful APIs** written in Python.
  * Integration with **GenAI toolkits** like:

    * **LangChain**
    * **LlamaIndex**
    * **OpenChat / ChatCompletion**
    * **Agent SDKs**
* Python is used both for:

  * Serving backend endpoints (API + orchestration layer).
  * Engaging AI services (retrieval-augmented generation, chatbots, agent orchestration).

So AGEX is leveraging Python as the **server + AI integration hub**.

---

## **Databases**

* Job descriptions explicitly list **SQL (relational)** and **NoSQL** databases.
* Likely examples:

  * **Relational:** PostgreSQL, MySQL
  * **NoSQL:** MongoDB, DynamoDB, or Cassandra (depending on scaling needs).
* This hybrid approach lets them handle both **structured customer/transactional data** and **unstructured conversational/AI context data**.

---

### ✅ **Summary Table**

| Layer       | Tech in Use                                                             |
| ----------- | ----------------------------------------------------------------------- |
| Frontend    | **React** (likely), Angular also possible                               |
| Backend     | **Python** (REST APIs, AI orchestration)                                |
| AI Services | LangChain, LlamaIndex, Agent SDKs, OpenChat/ChatCompletion              |
| Databases   | **Relational (PostgreSQL/MySQL)** + **NoSQL (MongoDB/Cassandra, etc.)** |

---

Do you want me to **map this into a reference system design diagram** (frontend → backend → AI services → DB) so it’s easier to visualize how AGEX likely structures their stack?


# Here’s a clear picture of how and why this app mixes SQL and NoSQL, and where each is used.

## What goes where

- SQL (Postgres via SQLModel)
  - Entities: users, chat_messages
  - Properties: strong consistency, relations, constraints, transactions, predictable schemas
  - Used for: core transactional data you need to trust, join, paginate, and evolve with migrations
- NoSQL (MongoDB)
  - Entities: operational logs (e.g., chat_logs), flexible metadata
  - Properties: schema-flexible, easy append, good for high-volume logs/events and ad-hoc fields
  - Used for: quick, schemaless logging and analytics-friendly event data

## How it’s wired in this repo

- Users and messages are stored in SQL:
  - Models: `User`, `ChatMessage` in models.py
  - Tables: `users`, `chat_messages` with FK `chat_messages.user_id -> users.id`
  - Endpoints:
    - `POST /api/users` writes to Postgres
    - `GET /api/users` reads from Postgres
- Logs are stored in Mongo:
  - Code: mongo.py provides a client; routers.py uses `get_mongo_db()`
  - Endpoint:
    - `POST /api/chat` does both:
      1) Writes user/assistant messages to Postgres (transactional history)
      2) Inserts a `{ user_id, message }` doc into Mongo’s `chat_logs` (operational log)

## Why this split (polyglot persistence)

- Data integrity and relationships (SQL)
  - Users and their messages benefit from constraints, referential integrity, and clear schema.
  - Query patterns (by user, time, pagination) and migrations are first-class in SQL.
- Flexibility and speed for logs (NoSQL)
  - Logs and event payloads change often; Mongo lets you add fields without migrations.
  - Great for aggregations, dashboards, and future analytics pipelines.
- Scaling and cost control
  - Keep transactional tables lean; offload verbose/denormalized logs to Mongo.
  - Index and scale each store independently for its workload.
- Team velocity
  - Product changes often affect logs first; schema-less logging reduces friction.
  - You can enrich logs later (prompt tokens, latency, model, experiment tags) without DB migrations.

## Typical queries and ops

- SQL (Postgres)
  - “List users,” “Fetch chat history for user,” “Find last N messages”
  - Benefits from indexes on `users.email`, `chat_messages.user_id, created_at`
- NoSQL (Mongo)
  - “Count chats per user,” “Daily requests by model,” “Top prompts by length”
  - Flexible fields for A/B flags, retries, error info

## Extension ideas

- Add analytics/observability fields to `chat_logs` (latency, token counts, model, status)
- Create Mongo indexes on `{ user_id: 1, timestamp: -1 }` for reporting
- Keep SQL migrations via Alembic; keep Mongo migrations optional and code-driven
- If you add retrieval/embeddings later, store vectors in a dedicated vector DB or in Mongo with a vector index (provider-dependent), while keeping user/message identity in SQL

In short: SQL is your source of truth for user-centric, relational data; Mongo captures flexible, high-volume operational data. This lets you keep the core consistent and the edge adaptable, and scale each part independently.