"""Guardian alert service - creates alerts for linked guardians when high-risk scans occur"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime

from app.models import User, Scan, GuardianLink, GuardianAlert, UserSettings


class GuardianAlertService:
    """Service to manage guardian alerts based on user threshold settings"""
    
    async def create_alerts_for_scan(
        self,
        db: AsyncSession,
        user: User,
        scan: Scan
    ) -> int:
        """
        Create guardian alerts for a scan based on user's threshold settings.
        Returns number of alerts created.
        """
        
        # Get user's alert threshold setting
        settings_result = await db.execute(
            select(UserSettings).where(UserSettings.user_id == user.id)
        )
        settings = settings_result.scalar_one_or_none()
        
        # Default threshold is HIGH
        threshold = settings.alert_guardians_threshold if settings else "HIGH"
        
        # Check if this scan meets the threshold
        should_alert = self._should_alert(scan.risk_level.value, threshold)
        
        if not should_alert:
            return 0
        
        # Get all active guardian links for this user
        links_result = await db.execute(
            select(GuardianLink).where(
                GuardianLink.user_id == user.id,
                GuardianLink.status == "active"
            )
        )
        links = links_result.scalars().all()
        
        alerts_created = 0
        
        for link in links:
            if link.guardian_account_id:
                # Create alert for this guardian
                alert = GuardianAlert(
                    guardian_account_id=link.guardian_account_id,
                    user_id=user.id,
                    scan_id=scan.id,
                    status="pending"
                )
                db.add(alert)
                alerts_created += 1
        
        if alerts_created > 0:
            # Mark scan as guardian_alerted
            scan.guardian_alerted = True
            await db.commit()
        
        return alerts_created
    
    def _should_alert(self, risk_level: str, threshold: str) -> bool:
        """
        Determine if alert should be sent based on threshold.
        
        Thresholds:
        - HIGH: Only alert on HIGH risk
        - MEDIUM: Alert on HIGH or MEDIUM
        - ALL: Alert on everything including LOW
        """
        
        if threshold == "HIGH":
            return risk_level == "HIGH"
        elif threshold == "MEDIUM":
            return risk_level in ["HIGH", "MEDIUM"]
        elif threshold == "ALL":
            return True
        else:
            return risk_level == "HIGH"  # Default to HIGH only


# Singleton instance
guardian_alert_service = GuardianAlertService()


async def send_guardian_alerts(db: AsyncSession, user: User, scan: Scan, result: dict):
    """
    Background task to create guardian alerts.
    Called from SMS analysis endpoint when HIGH risk detected.
    """
    try:
        alerts_created = await guardian_alert_service.create_alerts_for_scan(db, user, scan)
        print(f"DEBUG: Created {alerts_created} guardian alerts for scan {scan.id}")
    except Exception as e:
        print(f"ERROR: Failed to create guardian alerts: {e}")
