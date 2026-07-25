from fastapi import APIRouter, Depends, File, Query, UploadFile
from starlette.responses import Response

from app.core.deps import require_role
from app.models.push_token import PushTokenRequest
from app.models.user import UserProfileSetup, UserUpdate
from app.services import user_service, trip_service

router = APIRouter(prefix="/users", tags=["users"])

_client_auth = Depends(require_role("client"))


@router.get("/me")
async def get_me(user: dict = _client_auth) -> dict:
    return await user_service.get_user(user["id"])


@router.put("/me")
async def update_me(body: UserUpdate, user: dict = _client_auth) -> dict:
    return await user_service.update_user(user["id"], body)


@router.post("/me/profile-setup")
async def profile_setup(body: UserProfileSetup, user: dict = _client_auth) -> dict:
    return await user_service.complete_profile(user["id"], body)


@router.put("/me/avatar")
async def update_avatar(
    file: UploadFile = File(...),
    user: dict = _client_auth,
) -> dict:
    return await user_service.update_avatar(user["id"], file)


@router.get("/me/trips")
async def list_my_trips(
    user: dict = _client_auth,
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1),
) -> dict:
    return await user_service.get_user_trips(user["id"], page, limit)


@router.get("/me/active-trip")
async def get_active_trip(user: dict = _client_auth) -> dict:
    trip = await trip_service.get_active_trip_for_client(user["id"])
    return {"trip": trip}


@router.get("/me/trips/{trip_id}")
async def get_my_trip(trip_id: str, user: dict = _client_auth) -> dict:
    return await user_service.get_user_trip(user["id"], trip_id)


@router.delete("/me", status_code=204, response_class=Response)
async def delete_me(user: dict = _client_auth) -> Response:
    await user_service.delete_user(user["id"])
    return Response(status_code=204)


@router.post("/me/push-token")
async def register_push_token(body: PushTokenRequest, user: dict = _client_auth) -> dict:
    return await user_service.upsert_push_token(user["id"], body)


@router.delete("/me/push-token", status_code=204, response_class=Response)
async def delete_push_token(user: dict = _client_auth) -> Response:
    await user_service.remove_push_token(user["id"])
    return Response(status_code=204)
