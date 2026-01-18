"""
URL Scraping Service
Extract and analyze content from URLs for scam detection
"""
import re
import httpx
from urllib.parse import urlparse
from typing import Optional


class UrlScraperService:
    """Service to scrape and analyze URL content for scam detection"""
    
    # Common scam domain patterns
    SUSPICIOUS_PATTERNS = [
        r'(paypal|amazon|google|microsoft|apple|bank)\d+\.',  # Fake domains like paypal123.com
        r'\.(tk|ml|ga|cf|gq)$',  # Free TLDs often used for scams
        r'login.*verify',  # Phishing patterns
        r'account.*suspended',
        r'urgent.*action',
        r'\.xyz$',  # Suspicious TLD
        r'bit\.ly|tinyurl|t\.co',  # URL shorteners
    ]
    
    # Known legitimate domains (whitelist)
    SAFE_DOMAINS = [
        'google.com', 'amazon.in', 'amazon.com', 'flipkart.com', 
        'paypal.com', 'paytm.com', 'phonepe.com', 'gpay.com',
        'sbi.co.in', 'hdfc.com', 'icicibank.com', 'axisbank.com',
        'gov.in', 'nic.in'
    ]
    
    def __init__(self):
        self.client = httpx.AsyncClient(
            timeout=10.0,
            follow_redirects=True,
            headers={
                'User-Agent': 'Mozilla/5.0 (compatible; DetoozBot/1.0; +https://detooz.app)'
            }
        )
    
    async def analyze_url(self, url: str) -> dict:
        """
        Analyze a URL for scam indicators.
        Returns risk assessment without requiring full page scrape.
        """
        
        # Normalize URL
        if not url.startswith(('http://', 'https://')):
            url = 'https://' + url
        
        try:
            parsed = urlparse(url)
            domain = parsed.netloc.lower()
            
            # Check if it's a known safe domain
            for safe in self.SAFE_DOMAINS:
                if domain.endswith(safe):
                    return {
                        "url": url,
                        "domain": domain,
                        "risk_level": "LOW",
                        "reason": f"Known legitimate domain: {safe}",
                        "confidence": 0.9,
                        "is_reachable": True
                    }
            
            # Check suspicious patterns
            for pattern in self.SUSPICIOUS_PATTERNS:
                if re.search(pattern, url, re.IGNORECASE):
                    return {
                        "url": url,
                        "domain": domain,
                        "risk_level": "HIGH",
                        "reason": f"URL matches known scam pattern",
                        "confidence": 0.85,
                        "scam_type": "Suspicious URL",
                        "is_reachable": None
                    }
            
            # Try to fetch the page
            content_analysis = await self._fetch_and_analyze(url, domain)
            return content_analysis
            
        except Exception as e:
            return {
                "url": url,
                "domain": urlparse(url).netloc if url else "unknown",
                "risk_level": "MEDIUM",
                "reason": f"Could not analyze URL: {str(e)}",
                "confidence": 0.5,
                "is_reachable": False
            }
    
    async def _fetch_and_analyze(self, url: str, domain: str) -> dict:
        """Fetch URL and analyze content for scam indicators"""
        
        try:
            response = await self.client.get(url)
            
            if response.status_code != 200:
                return {
                    "url": url,
                    "domain": domain,
                    "risk_level": "MEDIUM",
                    "reason": f"URL returned status {response.status_code}",
                    "confidence": 0.6,
                    "is_reachable": True
                }
            
            content = response.text.lower()
            
            # Check for phishing indicators in content
            phishing_keywords = [
                'enter your password', 'verify your account', 'suspended',
                'click here immediately', 'your account will be blocked',
                'enter otp', 'share otp', 'kyc update required',
                'you have won', 'claim your prize', 'lottery winner'
            ]
            
            matches = [kw for kw in phishing_keywords if kw in content]
            
            if len(matches) >= 2:
                return {
                    "url": url,
                    "domain": domain,
                    "risk_level": "HIGH",
                    "reason": f"Page contains phishing content: {', '.join(matches[:3])}",
                    "confidence": 0.8,
                    "scam_type": "Phishing",
                    "is_reachable": True
                }
            elif len(matches) == 1:
                return {
                    "url": url,
                    "domain": domain,
                    "risk_level": "MEDIUM",
                    "reason": f"Page contains suspicious content: {matches[0]}",
                    "confidence": 0.6,
                    "is_reachable": True
                }
            
            # Check for form asking for sensitive info
            if '<input type="password"' in content or 'credit card' in content:
                return {
                    "url": url,
                    "domain": domain,
                    "risk_level": "MEDIUM",
                    "reason": "Page requests sensitive information",
                    "confidence": 0.65,
                    "is_reachable": True
                }
            
            return {
                "url": url,
                "domain": domain,
                "risk_level": "LOW",
                "reason": "No obvious scam indicators found",
                "confidence": 0.7,
                "is_reachable": True
            }
            
        except httpx.TimeoutException:
            return {
                "url": url,
                "domain": domain,
                "risk_level": "MEDIUM",
                "reason": "URL took too long to respond",
                "confidence": 0.5,
                "is_reachable": False
            }
        except Exception as e:
            return {
                "url": url,
                "domain": domain,
                "risk_level": "MEDIUM",
                "reason": f"Could not fetch URL: {str(e)[:50]}",
                "confidence": 0.5,
                "is_reachable": False
            }
    
    def normalize_phone(self, phone: str) -> str:
        """Normalize phone number to standard format"""
        # Remove all non-digits
        digits = re.sub(r'[^\d+]', '', phone)
        
        # Handle Indian numbers
        if digits.startswith('+91'):
            return digits
        elif digits.startswith('91') and len(digits) == 12:
            return '+' + digits
        elif len(digits) == 10:
            return '+91' + digits
        
        return digits
    
    async def close(self):
        """Close the HTTP client"""
        await self.client.aclose()


# Global instance
url_scraper = UrlScraperService()
