"""
Explanation Engine
Generates "Why Should I Care?" explanations for detected scams
"""
from typing import Optional


class ExplanationEngine:
    """
    Generate context-aware consequences and explanations for different scam types.
    Helps users understand the real-world impact of potential scams.
    """
    
    # Scam type to consequence mapping
    CONSEQUENCES = {
        "KYC Scam": {
            "headline": "Your bank account could be emptied",
            "details": [
                "Scammers will use your details to access your bank account",
                "They may take loans in your name",
                "Your credit score could be damaged"
            ],
            "action": "Never share OTP, CVV, or passwords. Banks NEVER ask for these.",
            "severity": "critical",
            "potential_loss": "₹50,000 - ₹10,00,000"
        },
        "Lottery Scam": {
            "headline": "There is no prize - you'll lose money",
            "details": [
                "Fake lotteries ask for 'processing fees' upfront",
                "Once paid, they'll ask for more or disappear",
                "Your personal details will be sold to other scammers"
            ],
            "action": "Real lotteries never ask winners to pay fees.",
            "severity": "high",
            "potential_loss": "₹5,000 - ₹1,00,000"
        },
        "Job Scam": {
            "headline": "No real job exists - only losses",
            "details": [
                "Registration fees are never returned",
                "Your documents may be misused for identity theft",
                "Some scams lead to illegal activities in your name"
            ],
            "action": "Legitimate companies never charge job seekers.",
            "severity": "high",
            "potential_loss": "₹1,000 - ₹50,000"
        },
        "OTP Fraud": {
            "headline": "Your money will be stolen in seconds",
            "details": [
                "OTP gives direct access to your bank account",
                "Transactions happen instantly and are hard to reverse",
                "Multiple accounts linked to your phone are at risk"
            ],
            "action": "NEVER share OTP with anyone. Not even bank officials.",
            "severity": "critical",
            "potential_loss": "Entire account balance"
        },
        "Loan Scam": {
            "headline": "You'll pay for a loan that never comes",
            "details": [
                "Processing fees are taken but loan never approved",
                "Your documents may be used for fraud",
                "Harassment calls may follow for months"
            ],
            "action": "Apply for loans only through official bank channels.",
            "severity": "high",
            "potential_loss": "₹2,000 - ₹25,000"
        },
        "UPI Fraud": {
            "headline": "Money goes out, not in",
            "details": [
                "Scanning QR codes to 'receive' money actually sends money",
                "Payment requests masked as incoming payments",
                "No way to reverse UPI transactions"
            ],
            "action": "Never scan QR or enter PIN to receive money.",
            "severity": "critical",
            "potential_loss": "₹1,000 - ₹2,00,000"
        },
        "Investment Scam": {
            "headline": "Guaranteed returns = Guaranteed fraud",
            "details": [
                "Ponzi schemes collapse taking all your money",
                "Crypto scams use complex terms to confuse",
                "Recovery is almost impossible"
            ],
            "action": "No investment guarantees returns. If it sounds too good, it is.",
            "severity": "critical",
            "potential_loss": "₹10,000 - ₹50,00,000"
        },
        "Delivery Scam": {
            "headline": "No package exists - your data will be stolen",
            "details": [
                "Links lead to fake sites that steal payment info",
                "'Customs fees' are pocketed by scammers",
                "Malware may be installed on your device"
            ],
            "action": "Track packages only on official courier websites.",
            "severity": "medium",
            "potential_loss": "₹500 - ₹5,000"
        },
        "Tech Support Scam": {
            "headline": "They'll gain control of your computer",
            "details": [
                "Remote access lets them see everything",
                "Bank passwords, photos, documents - all visible",
                "They may lock your device for ransom"
            ],
            "action": "Microsoft/Apple never call you. Hang up immediately.",
            "severity": "critical",
            "potential_loss": "₹5,000 - ₹5,00,000"
        },
        "Romance Scam": {
            "headline": "The person is fake, the losses are real",
            "details": [
                "Photos are stolen from other people",
                "Emotional manipulation leads to large payments",
                "Victims often lose life savings"
            ],
            "action": "Never send money to someone you haven't met in person.",
            "severity": "high",
            "potential_loss": "₹50,000 - ₹50,00,000"
        },
        "Phishing": {
            "headline": "Your credentials will be stolen",
            "details": [
                "Fake websites capture your login details",
                "Hackers access your email, social media, bank",
                "Your identity can be used for crimes"
            ],
            "action": "Always check the URL carefully. Look for https and correct spelling.",
            "severity": "high",
            "potential_loss": "Varies - up to full accounts"
        },
        "Blocked Sender": {
            "headline": "This sender was previously blocked",
            "details": [
                "You or the system already marked this as harmful",
                "They may be trying new tactics",
                "Continue ignoring messages from this sender"
            ],
            "action": "Keep this sender blocked. Report if harassment continues.",
            "severity": "medium",
            "potential_loss": "N/A - Already protected"
        }
    }
    
    # Default for unknown scam types
    DEFAULT_CONSEQUENCE = {
        "headline": "This message shows signs of a scam",
        "details": [
            "Scammers use urgency and fear to manipulate",
            "Any money sent is unlikely to be recovered",
            "Your personal details may be misused"
        ],
        "action": "When in doubt, don't respond. Verify through official channels.",
        "severity": "medium",
        "potential_loss": "Varies"
    }
    
    # Hindi translations of key phrases
    HINDI_TRANSLATIONS = {
        "Your bank account could be emptied": "आपका बैंक खाता खाली हो सकता है",
        "There is no prize - you'll lose money": "कोई इनाम नहीं है - आप पैसे खो देंगे",
        "Your money will be stolen in seconds": "सेकंडों में आपका पैसा चोरी हो जाएगा",
        "Never share OTP with anyone": "OTP किसी के साथ साझा न करें",
        "When in doubt, don't respond": "संदेह होने पर, जवाब न दें"
    }
    
    def get_explanation(
        self, 
        risk_level: str, 
        scam_type: Optional[str] = None,
        language: str = "en"
    ) -> dict:
        """
        Generate explanation for a detected scam.
        
        Args:
            risk_level: HIGH, MEDIUM, or LOW
            scam_type: Type of scam detected (optional)
            language: "en" for English, "hi" for Hindi
        
        Returns:
            Explanation with headline, details, action items
        """
        
        if risk_level == "LOW":
            return {
                "headline": "This appears safe",
                "details": ["No scam indicators detected"],
                "action": "Stay vigilant with all messages",
                "severity": "low",
                "potential_loss": "None expected",
                "should_worry": False
            }
        
        # Get consequence for scam type
        consequence = self.CONSEQUENCES.get(
            scam_type, 
            self.DEFAULT_CONSEQUENCE
        )
        
        # Add worry factor
        should_worry = risk_level == "HIGH" or consequence["severity"] == "critical"
        
        result = {
            "headline": consequence["headline"],
            "details": consequence["details"],
            "action": consequence["action"],
            "severity": consequence["severity"],
            "potential_loss": consequence["potential_loss"],
            "should_worry": should_worry,
            "scam_type": scam_type
        }
        
        # Add Hindi translation if requested
        if language == "hi":
            result["headline_hi"] = self.HINDI_TRANSLATIONS.get(
                consequence["headline"],
                consequence["headline"]
            )
        
        return result
    
    def get_quick_tip(self, scam_type: Optional[str] = None) -> str:
        """Get a one-liner tip for the scam type"""
        tips = {
            "KYC Scam": "Banks never ask for OTP or password via SMS/call",
            "Lottery Scam": "You can't win a lottery you didn't enter",
            "OTP Fraud": "OTP is like your password - never share it",
            "UPI Fraud": "You never need to enter PIN to receive money",
            "Job Scam": "Real jobs pay you, not the other way around",
            "Investment Scam": "If returns are guaranteed, it's a scam",
            "Phishing": "Check URLs carefully before entering credentials",
        }
        return tips.get(scam_type, "Verify before you trust")
    
    def get_all_scam_types(self) -> list:
        """Return list of all known scam types"""
        return list(self.CONSEQUENCES.keys())


# Global instance
explanation_engine = ExplanationEngine()
