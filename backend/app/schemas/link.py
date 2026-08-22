"""MAYA — Link Player & External Media Schemas"""
from datetime import datetime
from typing import Optional
from pydantic import BaseModel, HttpUrl, field_validator


class LinkResolveRequest(BaseModel):
    url: str

    @field_validator("url")
    @classmethod
    def url_not_empty(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("URL must not be empty.")
        if not v.startswith(("http://", "https://")):
            raise ValueError("URL must start with http:// or https://")
        return v


class LinkResolveResponse(BaseModel):
    success: bool
    title: Optional[str] = None
    thumbnail: Optional[str] = None
    duration: Optional[int] = None
    media_type: Optional[str] = None
    stream_type: Optional[str] = None
    stream_url: Optional[str] = None
    provider: Optional[str] = None
    source_url: Optional[str] = None
    expires_at: Optional[datetime] = None
    error: Optional[str] = None
    error_code: Optional[str] = None


class ExternalMediaCreate(BaseModel):
    title: str = "External Media"
    thumbnail: Optional[str] = None
    duration: Optional[int] = None
    source_url: str
    provider: Optional[str] = None
    stream_type: Optional[str] = None
    media_type: Optional[str] = None


class ExternalMediaResponse(BaseModel):
    id: int
    title: str
    thumbnail: Optional[str] = None
    duration: Optional[int] = None
    source_url: str
    provider: Optional[str] = None
    stream_type: Optional[str] = None
    media_type: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}
