from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from datetime import datetime
from app.routers.auth import get_current_user
from app.services.alert_service import AlertService

router = APIRouter()
alert_service = AlertService()


class GuardianCreate(BaseModel):
    name: str
    phone: str
    callmebot_apikey: str | None = None


class GuardianResponse(BaseModel):
    id: int
    name: str
    phone: str
    is_verified: bool
    last_alert_sent: datetime | None
    created_at: datetime


class GuardianUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None
    callmebot_apikey: str | None = None


# In-memory guardian store (replace with database)
guardians_db = {}
guardian_id_counter = 1


@router.get("/list", response_model=list[GuardianResponse])
async def list_guardians(current_user: dict = Depends(get_current_user)):
    """List all guardians for current user"""
    user_guardians = guardians_db.get(current_user["id"], [])
    return [GuardianResponse(**g) for g in user_guardians]


@router.post("/add", response_model=GuardianResponse)
async def add_guardian(
    guardian: GuardianCreate,
    current_user: dict = Depends(get_current_user)
):
    """Add a new guardian"""
    global guardian_id_counter
    
    new_guardian = {
        "id": guardian_id_counter,
        "user_id": current_user["id"],
        "name": guardian.name,
        "phone": guardian.phone,
        "callmebot_apikey": guardian.callmebot_apikey,
        "is_verified": guardian.callmebot_apikey is not None,
        "last_alert_sent": None,
        "created_at": datetime.utcnow()
    }
    
    if current_user["id"] not in guardians_db:
        guardians_db[current_user["id"]] = []
    guardians_db[current_user["id"]].append(new_guardian)
    guardian_id_counter += 1
    
    return GuardianResponse(**new_guardian)


@router.put("/{guardian_id}", response_model=GuardianResponse)
async def update_guardian(
    guardian_id: int,
    update: GuardianUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update a guardian"""
    user_guardians = guardians_db.get(current_user["id"], [])
    
    for guardian in user_guardians:
        if guardian["id"] == guardian_id:
            if update.name:
                guardian["name"] = update.name
            if update.phone:
                guardian["phone"] = update.phone
            if update.callmebot_apikey:
                guardian["callmebot_apikey"] = update.callmebot_apikey
                guardian["is_verified"] = True
            return GuardianResponse(**guardian)
    
    raise HTTPException(status_code=404, detail="Guardian not found")


@router.delete("/{guardian_id}")
async def delete_guardian(
    guardian_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Delete a guardian"""
    user_guardians = guardians_db.get(current_user["id"], [])
    
    for i, guardian in enumerate(user_guardians):
        if guardian["id"] == guardian_id:
            del user_guardians[i]
            return {"message": "Guardian deleted"}
    
    raise HTTPException(status_code=404, detail="Guardian not found")


@router.post("/test-alert/{guardian_id}")
async def test_alert(
    guardian_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Send a test alert to guardian"""
    user_guardians = guardians_db.get(current_user["id"], [])
    
    for guardian in user_guardians:
        if guardian["id"] == guardian_id:
            if not guardian.get("callmebot_apikey"):
                raise HTTPException(
                    status_code=400,
                    detail="Guardian has no CallMeBot API key configured"
                )
            
            success = await alert_service.send_test_alert(
                phone=guardian["phone"],
                apikey=guardian["callmebot_apikey"],
                user_name=current_user["name"]
            )
            
            if success:
                guardian["last_alert_sent"] = datetime.utcnow()
                return {"message": "Test alert sent successfully"}
            else:
                raise HTTPException(
                    status_code=500,
                    detail="Failed to send test alert"
                )
    
    raise HTTPException(status_code=404, detail="Guardian not found")
