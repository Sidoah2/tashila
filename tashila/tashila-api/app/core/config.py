import os

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        extra="ignore",
    )

    port: int = 8000
    environment: str = "development"
    mongo_uri: str
    mongo_db_name: str = "tashila"
    redis_url: str
    jwt_secret: str
    jwt_refresh_secret: str
    jwt_expire_minutes: int = 60
    jwt_refresh_expire_days: int = 30
    admin_jwt_secret: str
    admin_jwt_expire_minutes: int = 480
    fcm_server_key: str = ""
    traccar_sms_url: str = "https://www.traccar.org/sms/"
    traccar_sms_token: str = ""
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_phone_number: str = ""
    smssak_api_key: str = ""
    smssak_project_id: str = ""
    smssak_country: str = "dz"
    smssak_send_otp_url: str = "https://sendotp-47lvvvrp4a-uc.a.run.app"
    smssak_verify_otp_url: str = "https://verifyotp-47lvvvrp4a-uc.a.run.app"
    smssak_send_message_url: str = "https://sendmessage-47lvvvrp4a-uc.a.run.app"
    allowed_origins: str = "http://localhost:3000,http://localhost:3001,http://localhost:5173,http://127.0.0.1:3000,http://127.0.0.1:3001,https://tashilaadmin-tau.vercel.app,https://admin.tashila.dz,https://tashila-admin.vercel.app"
    upload_dir: str = "/tmp/tashila_uploads"
    cloudinary_url: str = ""
    test_otp_enabled: bool = False
    test_otp_code: str = "1111"
    test_phone_numbers: str = "+213611223344,+213711223344,0611223344,0711223344,611223344,711223344"
    test_otp_codes: str = "1111,1234,0000"
    max_otp_attempts: int = 5
    otp_window_seconds: int = 60
    firebase_credentials_path: str = "firebase-adminsdk.json"
    google_maps_api_key: str = ""

    offer_ttl_seconds: int = 180
    max_dispatch_candidates: int = 5
    # Short retry when geo query returns nobody (driver may come online momentarily).
    dispatch_no_candidate_grace_seconds: int = 8
    dispatch_retry_interval_seconds: int = 2
    reject_ttl_seconds: int = 3600
    dispatch_lock_ttl_seconds: int = 600

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    @property
    def cors_origins(self) -> list[str]:
        origins = []
        for raw in self.allowed_origins.split(","):
            cleaned = raw.strip().rstrip("/")
            if cleaned:
                origins.append(cleaned)
                # Also allow with trailing slash for browser compatibility
                origins.append(f"{cleaned}/")
        return list(dict.fromkeys(origins))


settings = Settings()
os.makedirs(settings.upload_dir, exist_ok=True)
