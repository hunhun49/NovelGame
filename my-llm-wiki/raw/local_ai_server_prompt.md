# Local AI Dialogue Server - Implementation Prompt

## Goal

Build a local AI dialogue server using FastAPI + Ollama + SQLite +
Vector DB.

## Requirements

-   FastAPI REST API
-   Ollama integration
-   SQLite database
-   Vector search (Chroma or FAISS)
-   Modular architecture (services, repositories)

## Steps

### Step 1: Setup FastAPI project

-   Create FastAPI app
-   Add `/chat` endpoint

### Step 2: Connect Ollama

-   Call local Ollama API (http://localhost:11434)
-   Send prompt and receive response

### Step 3: Database

-   Create SQLite models:
    -   users
    -   characters
    -   user_character_state
    -   dialogue_logs

### Step 4: Prompt Builder

-   Combine:
    -   character personality
    -   recent conversation
    -   user input

### Step 5: Memory

-   Store dialogue logs
-   Retrieve last N conversations

### Step 6: Vector DB

-   Store event embeddings
-   Retrieve similar events

### Step 7: Structure

    app/
      api/
      services/
      models/
      repositories/

## Output

-   JSON response: { "reply": "...", "emotion": "...", "memory_refs":
    \[\] }
