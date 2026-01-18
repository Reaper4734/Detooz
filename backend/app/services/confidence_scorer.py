"""
Confidence Scoring Service
Advanced confidence calibration and score smoothing for scam detection
"""
from typing import Optional, List, Dict
from dataclasses import dataclass


@dataclass
class ConfidenceFactors:
    """Factors that affect confidence scoring"""
    pattern_match: float = 0.0
    ai_confidence: float = 0.0
    reputation_score: float = 0.0
    sender_history: float = 0.0
    message_length: float = 0.0
    urgency_level: float = 0.0


class ConfidenceScoringService:
    """
    Advanced confidence calibration for scam detection.
    Combines multiple signals into a normalized confidence score.
    """
    
    # Weights for different scoring factors
    WEIGHTS = {
        "pattern_match": 0.30,    # Local pattern matching
        "ai_confidence": 0.35,    # AI model confidence
        "reputation": 0.15,       # Known reputation
        "sender_history": 0.10,   # User's history with sender
        "context": 0.10          # Message context/urgency
    }
    
    # Confidence thresholds for risk bands
    THRESHOLDS = {
        "HIGH": 0.75,
        "MEDIUM": 0.45,
        "LOW": 0.0
    }
    
    def calculate_confidence(
        self,
        pattern_confidence: float = 0.0,
        ai_confidence: float = 0.0,
        reputation_score: float = 0.0,
        sender_trusted: bool = False,
        sender_blocked: bool = False,
        has_urgency: bool = False,
        has_links: bool = False,
        message_length: int = 0
    ) -> dict:
        """
        Calculate calibrated confidence score.
        
        Returns:
            {
                "confidence": float (0-1),
                "risk_level": str,
                "factors": dict,
                "explanation": str
            }
        """
        
        # Handle edge cases
        if sender_blocked:
            return {
                "confidence": 1.0,
                "risk_level": "HIGH",
                "factors": {"blocked_sender": 1.0},
                "explanation": "Sender is on block list"
            }
        
        if sender_trusted:
            return {
                "confidence": 0.1,
                "risk_level": "LOW",
                "factors": {"trusted_sender": 1.0},
                "explanation": "Sender is marked as trusted"
            }
        
        # Calculate individual factors
        factors = ConfidenceFactors()
        
        # Pattern matching factor (0-1)
        factors.pattern_match = min(pattern_confidence, 1.0)
        
        # AI confidence factor (0-1)
        factors.ai_confidence = min(ai_confidence, 1.0)
        
        # Reputation factor (0-1, higher = more suspicious)
        factors.reputation_score = min(reputation_score, 1.0)
        
        # Context factors
        context_score = 0.0
        if has_urgency:
            context_score += 0.3
        if has_links:
            context_score += 0.2
        if message_length < 50:  # Short messages are more suspicious
            context_score += 0.1
        elif message_length > 500:  # Very long messages might be spam
            context_score += 0.1
            
        factors.urgency_level = min(context_score, 1.0)
        
        # Calculate weighted score
        weighted_score = (
            self.WEIGHTS["pattern_match"] * factors.pattern_match +
            self.WEIGHTS["ai_confidence"] * factors.ai_confidence +
            self.WEIGHTS["reputation"] * factors.reputation_score +
            self.WEIGHTS["context"] * factors.urgency_level
        )
        
        # Apply smoothing function (sigmoid-like)
        smoothed_score = self._smooth_score(weighted_score)
        
        # Determine risk level
        risk_level = self._get_risk_level(smoothed_score)
        
        # Generate explanation
        explanation = self._generate_explanation(factors, risk_level)
        
        return {
            "confidence": round(smoothed_score, 3),
            "risk_level": risk_level,
            "factors": {
                "pattern_match": round(factors.pattern_match, 2),
                "ai_confidence": round(factors.ai_confidence, 2),
                "reputation": round(factors.reputation_score, 2),
                "context": round(factors.urgency_level, 2)
            },
            "explanation": explanation
        }
    
    def _smooth_score(self, raw_score: float) -> float:
        """
        Apply smoothing to avoid extreme values.
        Uses a modified sigmoid to keep scores in reasonable range.
        """
        # Ensure score is bounded
        raw_score = max(0, min(1, raw_score))
        
        # Apply slight sigmoid curve for smoothing
        # This prevents scores from clustering at 0 or 1
        if raw_score <= 0.1:
            return raw_score * 1.5  # Boost very low scores slightly
        elif raw_score >= 0.9:
            return 0.85 + (raw_score - 0.9) * 1.5  # Cap very high scores
        else:
            return raw_score
    
    def _get_risk_level(self, confidence: float) -> str:
        """Map confidence score to risk level"""
        if confidence >= self.THRESHOLDS["HIGH"]:
            return "HIGH"
        elif confidence >= self.THRESHOLDS["MEDIUM"]:
            return "MEDIUM"
        else:
            return "LOW"
    
    def _generate_explanation(self, factors: ConfidenceFactors, risk_level: str) -> str:
        """Generate human-readable explanation of confidence factors"""
        
        explanations = []
        
        if factors.pattern_match > 0.5:
            explanations.append("matches known scam patterns")
        
        if factors.ai_confidence > 0.6:
            explanations.append("AI detected suspicious content")
        
        if factors.reputation_score > 0.5:
            explanations.append("sender/URL has negative reputation")
        
        if factors.urgency_level > 0.3:
            explanations.append("message creates urgency")
        
        if not explanations:
            if risk_level == "LOW":
                return "No significant risk indicators found"
            else:
                return "Multiple minor risk factors detected"
        
        return "Detected: " + ", ".join(explanations)
    
    def combine_scores(
        self,
        local_score: float,
        ai_score: float,
        prefer_local: bool = False
    ) -> float:
        """
        Combine local pattern score with AI score.
        Used when both methods produce results.
        """
        if prefer_local and local_score > 0.8:
            # High local confidence - trust patterns
            return local_score
        
        if ai_score == 0:
            return local_score
        
        if local_score == 0:
            return ai_score
        
        # Weighted average, favoring higher score
        max_score = max(local_score, ai_score)
        min_score = min(local_score, ai_score)
        
        # Give 70% weight to higher score
        return 0.7 * max_score + 0.3 * min_score
    
    def calibrate_for_risk_level(
        self,
        raw_risk_level: str,
        raw_confidence: float
    ) -> dict:
        """
        Ensure risk level and confidence are consistent.
        Adjusts confidence if needed to match risk level.
        """
        
        thresholds = {
            "HIGH": (0.75, 1.0),
            "MEDIUM": (0.45, 0.74),
            "LOW": (0.0, 0.44)
        }
        
        min_conf, max_conf = thresholds.get(raw_risk_level, (0.0, 1.0))
        
        # Adjust confidence to be within expected range for risk level
        if raw_confidence < min_conf:
            adjusted = min_conf + 0.05
        elif raw_confidence > max_conf:
            adjusted = max_conf
        else:
            adjusted = raw_confidence
        
        return {
            "risk_level": raw_risk_level,
            "confidence": round(adjusted, 2),
            "adjusted": raw_confidence != adjusted
        }


# Global instance
confidence_scorer = ConfidenceScoringService()
