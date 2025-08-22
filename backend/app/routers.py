from typing import List, Dict

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import select, Session

from .db import get_session
from .models import User, ChatMessage
from .genai import genai_client
from .mongo import get_mongo_db


router = APIRouter()


@router.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


@router.post("/users", response_model=User)
def create_user(user: User, session: Session = Depends(get_session)) -> User:
    existing = session.exec(select(User).where(User.email == user.email)).first()
    if existing:
        raise HTTPException(status_code=409, detail="User already exists")
    session.add(user)
    session.commit()
    session.refresh(user)
    return user


@router.get("/users", response_model=List[User])
def list_users(session: Session = Depends(get_session)) -> List[User]:
    return list(session.exec(select(User)))


@router.post("/chat")
def chat(user_id: int, message: str, session: Session = Depends(get_session)) -> Dict[str, str]:
    # persist user message to SQL
    user_msg = ChatMessage(user_id=user_id, role="user", content=message)
    session.add(user_msg)
    session.commit()
    session.refresh(user_msg)

    # write a basic usage log to Mongo
    mongo = get_mongo_db()
    mongo["chat_logs"].insert_one({"user_id": user_id, "message": message})

    # call GenAI
    reply = genai_client.chat([
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": message},
    ])

    # persist assistant reply
    asst_msg = ChatMessage(user_id=user_id, role="assistant", content=reply)
    session.add(asst_msg)
    session.commit()

    return {"reply": reply}
