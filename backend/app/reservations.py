from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from typing import List, Optional
from uuid import uuid4
from datetime import datetime


router = APIRouter()


class Passenger(BaseModel):
    name: str
    pmr_profile: Optional[str] = Field(
        default=None, description="Profile PMR (fauteuil, canne, déficience visuelle, etc.)"
    )


class ReservationCreate(BaseModel):
    origin: str
    destination: str
    datetime_utc: datetime
    passenger: Passenger


class Reservation(ReservationCreate):
    id: str
    status: str = Field(default="pending", description="pending|confirmed|cancelled")


DB: dict[str, Reservation] = {}


@router.post("/reservations", response_model=Reservation)
def create_reservation(payload: ReservationCreate) -> Reservation:
    rid = str(uuid4())
    res = Reservation(id=rid, **payload.model_dump())
    DB[rid] = res
    return res


@router.get("/reservations/{reservation_id}", response_model=Reservation)
def get_reservation(reservation_id: str) -> Reservation:
    res = DB.get(reservation_id)
    if not res:
        raise HTTPException(status_code=404, detail="Reservation not found")
    return res


@router.get("/reservations", response_model=List[Reservation])
def list_reservations() -> List[Reservation]:
    return list(DB.values())

