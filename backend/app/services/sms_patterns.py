"""
Indian SMS Scam Patterns Database

This module contains regex patterns for detecting various types of SMS scams
common in India. Patterns are categorized by risk level and scam type.
"""

import re

# ============== HIGH RISK PATTERNS ==============
# These patterns indicate almost certain scams

HIGH_RISK_PATTERNS = {
    # KYC/Bank Scams
    "kyc_scam": [
        r"kyc\s*(update|expire|suspend|block|verify|pending)",
        r"(pan|aadhaar)\s*(link|update|verify|expire)\s*urgent",
        r"bank\s*account\s*(block|suspend|close|frozen)",
        r"atm\s*card\s*(block|suspend|expire)",
        r"dear\s*customer.*account.*block",
        r"your\s*a/c\s*will\s*be\s*blocked",
        r"complete\s*your\s*kyc\s*immediately",
    ],
    
    # Prize/Lottery Scams
    "prize_scam": [
        r"won\s*(lottery|prize|rs\.?|₹|lakh|crore|cash)",
        r"claim\s*(prize|reward|money|gift)",
        r"congratulations.*won",
        r"lucky\s*(winner|draw|customer)",
        r"selected\s*for\s*(prize|reward|cashback)",
        r"₹\s*\d+\s*(lakh|crore)\s*prize",
    ],
    
    # OTP/Password Theft
    "otp_scam": [
        r"send\s*(me\s*)?otp",
        r"share\s*(your\s*)?otp",
        r"otp\s*(is|:)\s*\d{4,6}.*share",
        r"tell\s*me\s*otp",
        r"give\s*otp",
        r"need\s*your\s*otp",
    ],
    
    # Job Scams
    "job_scam": [
        r"(job|work)\s*offer.*(payment|fee|deposit|registration)",
        r"part\s*time\s*job.*(pay|fee|deposit)",
        r"work\s*from\s*home.*earn\s*₹?\d+",
        r"hiring.*pay\s*registration",
        r"earn\s*₹\s*\d+.*per\s*(day|hour)",
    ],
    
    # Loan Scams
    "loan_scam": [
        r"loan\s*approved\s*(instantly|now|today)",
        r"pre-?approved\s*loan",
        r"instant\s*loan\s*₹",
        r"personal\s*loan.*processing\s*fee",
        r"loan\s*sanction.*pay\s*₹",
    ],
    
    # Investment Scams
    "investment_scam": [
        r"investment.*guaranteed\s*return",
        r"earn\s*\d+%\s*daily",
        r"double\s*your\s*money",
        r"crypto.*guaranteed\s*profit",
        r"trading\s*tips.*100%\s*profit",
    ],
    
    # Government Impersonation
    "govt_scam": [
        r"income\s*tax\s*refund.*click",
        r"it\s*department.*verify",
        r"govt\s*scheme.*registration\s*fee",
        r"pm\s*kisan.*verify\s*now",
        r"subsidy.*click\s*link",
    ],
    
    # Delivery Scams
    "delivery_scam": [
        r"package\s*(held|stuck).*pay\s*fee",
        r"customs\s*duty.*pay\s*₹",
        r"parcel\s*held.*verification",
        r"delivery\s*failed.*update\s*address",
    ],
}


# ============== MEDIUM RISK PATTERNS ==============
# These patterns are suspicious but not definitive

MEDIUM_RISK_PATTERNS = {
    # Suspicious links
    "suspicious_link": [
        r"bit\.ly",
        r"tinyurl",
        r"short\.io",
        r"t\.co",
        r"goo\.gl",
        r"link\.\w{2,4}/",
        r"click\s*here\s*now",
        r"click\s*this\s*link",
    ],
    
    # Urgency tactics
    "urgency": [
        r"act\s*now",
        r"urgent\s*action",
        r"expires?\s*(today|tonight|in\s*\d+\s*hours?)",
        r"last\s*chance",
        r"limited\s*time",
        r"offer\s*ends?\s*(today|soon)",
        r"respond\s*immediately",
        r"don't\s*miss",
    ],
    
    # Money requests
    "money_request": [
        r"transfer\s*₹?\d+",
        r"pay\s*₹?\d+\s*to",
        r"send\s*money",
        r"need\s*₹?\d+\s*urgently",
    ],
    
    # Verification requests
    "verification": [
        r"verify\s*your\s*(account|identity|details)",
        r"confirm\s*your\s*(details|account)",
        r"update\s*your\s*(profile|details)",
    ],
}


# ============== SAFE PATTERNS ==============
# Known legitimate sender patterns

SAFE_SENDER_PATTERNS = [
    r"^(VK-|VM-|BZ-|AD-|JD-|MD-|TD-|HP-|AX-)(HDFC|ICICI|SBI|AXIS|KOTAK|PNB|BOB|INDIAN)",
    r"^(VK-|VM-).*(BANK|INSUR|GOVT)",
    r"^IRCTC",
    r"^AMAZON",
    r"^FLIPKRT",
    r"^SWIGGY",
    r"^ZOMATO",
    r"^PAYTM",
    r"^GPAY",
    r"^PHONEPE",
]


def check_patterns(message: str, sender: str = "") -> dict:
    """
    Check message against all scam patterns.
    
    Returns:
        dict with risk_level, reason, scam_type, confidence, and matched_patterns
    """
    message_lower = message.lower()
    sender_upper = sender.upper() if sender else ""
    
    # Check if sender is from a known safe source
    for pattern in SAFE_SENDER_PATTERNS:
        if re.search(pattern, sender_upper):
            # Still check message content for scams (in case sender is spoofed)
            pass
    
    matched_high = []
    matched_medium = []
    
    # Check HIGH risk patterns
    for scam_type, patterns in HIGH_RISK_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, message_lower):
                matched_high.append({
                    "type": scam_type,
                    "pattern": pattern
                })
    
    # Check MEDIUM risk patterns
    for scam_type, patterns in MEDIUM_RISK_PATTERNS.items():
        for pattern in patterns:
            if re.search(pattern, message_lower):
                matched_medium.append({
                    "type": scam_type,
                    "pattern": pattern
                })
    
    # Determine risk level
    if matched_high:
        return {
            "risk_level": "HIGH",
            "reason": f"Detected {matched_high[0]['type'].replace('_', ' ')} pattern",
            "scam_type": matched_high[0]['type'],
            "confidence": min(0.85 + (len(matched_high) * 0.03), 0.99),
            "matched_patterns": matched_high
        }
    elif matched_medium:
        # Multiple medium patterns = higher risk
        if len(matched_medium) >= 3:
            return {
                "risk_level": "HIGH",
                "reason": "Multiple suspicious patterns detected",
                "scam_type": "Multiple Indicators",
                "confidence": 0.75,
                "matched_patterns": matched_medium
            }
        else:
            return {
                "risk_level": "MEDIUM",
                "reason": f"Detected {matched_medium[0]['type'].replace('_', ' ')}",
                "scam_type": matched_medium[0]['type'],
                "confidence": 0.5 + (len(matched_medium) * 0.1),
                "matched_patterns": matched_medium
            }
    else:
        return {
            "risk_level": "LOW",
            "reason": "No suspicious patterns detected",
            "scam_type": None,
            "confidence": 0.7,
            "matched_patterns": []
        }


def get_scam_types() -> dict:
    """Return all scam types with descriptions"""
    return {
        "kyc_scam": "Bank KYC/Account blocking scam",
        "prize_scam": "Fake lottery or prize scam",
        "otp_scam": "OTP stealing attempt",
        "job_scam": "Fake job offer requiring payment",
        "loan_scam": "Fake instant loan scam",
        "investment_scam": "Fake investment scheme",
        "govt_scam": "Government impersonation scam",
        "delivery_scam": "Fake delivery/customs scam",
        "suspicious_link": "Suspicious shortened link",
        "urgency": "Urgency tactics to pressure action",
        "money_request": "Direct money request",
        "verification": "Suspicious verification request",
    }
