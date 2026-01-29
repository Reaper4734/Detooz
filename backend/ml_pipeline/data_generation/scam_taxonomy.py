
"""
SCAM TAXONOMY (Indian Context 🇮🇳)
Defines the categories, keywords, and targets for the dataset generation.
"""

TOTAL_TARGET = 52000 

SCAM_TAXONOMY = {
    # ---------------------------
    # FINANCIAL FRAUD (High Vol)
    # ---------------------------
    "kyc_fraud": {
        "description": "Fake KYC update warnings (Bank/Wallet/SIM)",
        "keywords": ["KYC", "blocked", "PAN card", "Aadhaar", "update immediate", "suspend"],
        "target": 2500
    },
    "credit_card_points": {
        "description": "Fake reward points expiring redemption",
        "keywords": ["redeem", "points", "expire", "HDFC", "SBI", "ICICI", "bonus"],
        "target": 2500
    },
    "electricity_bill": {
        "description": "Power disconnection threat",
        "keywords": ["electricity", "bill", "disconnect", "tonight", "officer", "unpaid"],
        "target": 2000
    },
    "income_tax_refund": {
        "description": "Fake tax refund approval link",
        "keywords": ["ITR", "refund", "approved", "account", "deposit", "tax"],
        "target": 2000
    },
    "loan_app_harassment": {
        "description": "Predatory loan approval or harassment",
        "keywords": ["loan", "approved", "interest", "documents", "disburse", "limit"],
        "target": 1500
    },
    "stock_ipo_tip": {
        "description": "Fake stock tips/IPO allocation (WhatsApp groups)",
        "keywords": ["stock", "IPO", "profit", "multibagger", "invest", "guarantee"],
        "target": 3000
    },
    
    # ---------------------------
    # IMPERSONATION & THREATS
    # ---------------------------
    "digital_arrest": {
        "description": "Fake police/CBI threat of arrest (courier/drugs)",
        "keywords": ["CBI", "police", "arrest", "courier", "illegal", "drugs", "customs"],
        "target": 3000
    },
    "sextortion": {
        "description": "Threat to leak private video/photos",
        "keywords": ["video", "leak", "viral", "delete", "shame", "upload"],
        "target": 1500
    },
    "family_distress": {
        "description": "Fake emergency (hospital/arrest) of relative",
        "keywords": ["hospital", "accident", "urgent", "money", "kid", "son"],
        "target": 2500
    },
    "boss_ceo_fraud": {
        "description": "Impersonating boss asking for gift cards/transfer",
        "keywords": ["meeting", "urgent", "gift card", "transfer", "CEO", "boss"],
        "target": 1000
    },
    
    # ---------------------------
    # LIFESTYLE & OFFERS
    # ---------------------------
    "part_time_job": {
        "description": "Fake WFH/YouTube like tasks",
        "keywords": ["part time", "job", "salary", "daily income", "HR", "hiring"],
        "target": 3500
    },
    "mall_review_scam": {
        "description": "Paid to review hotels/malls (Task scam)",
        "keywords": ["review", "google maps", "hotel", "mall", "earn", "task"],
        "target": 1500
    },
    "lottery_kbc": {
        "description": "Fake KBC/Lottery winner announcement",
        "keywords": ["KBC", "lottery", "winner", "crore", "lakh", "WhatsApp"],
        "target": 2000
    },
    "romance_scam": {
        "description": "Fake love interest, gift customs fee",
        "keywords": ["love", "gift", "customs", "parcels", "airport", "honey"],
        "target": 2500
    },
    "pig_butchering": {
        "description": "Long-term investment grooming (Crypto/Forex)",
        "keywords": ["crypto", "USDT", "mining", "invest", "friend", "WhatsApp"],
        "target": 3000
    },
    
    # ---------------------------
    # SYSTEM & TECH
    # ---------------------------
    "sim_swap_trai": {
        "description": "Fake TRAI/Sim block warning",
        "keywords": ["TRAI", "SIM", "block", "24 hours", "e-sim", "verify"],
        "target": 2000
    },
    "apk_download_malware": {
        "description": "Links to download fake banking/reward apps",
        "keywords": ["download", "app", "apk", "install", "update", "bonus"],
        "target": 2500
    },
    "customer_care_scam": {
        "description": "Fake support number for refund/complaint",
        "keywords": ["customer care", "refund", "failed", "call", "support", "ticket"],
        "target": 2000
    },
    "challan_traffic": {
        "description": "Fake traffic fine link",
        "keywords": ["challan", "traffic", "police", "fine", "vehicle", "court"],
        "target": 1500
    },
    
    # ---------------------------
    # HAM (SAFE MESSAGES)
    # ---------------------------
    "safe_promotional": {
        "description": "Real marketing (Zomato, Myntra, Jio)",
        "keywords": ["deal", "offer", "sale", "discount", "order", "delivery"],
        "target": 5000
    },
    "safe_personal": {
        "description": "Personal chat (Friends, Family, Work)",
        "keywords": ["hey", "call me", "home", "dinner", "office", "late"],
        "target": 5000
    }
}
