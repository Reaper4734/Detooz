# Detooz GitHub History Analysis Report

## 1. Development Timeline & Phases
The Detooz project has evolved through three distinct developmental phases, starting from its foundational AI concepts to a production-ready, security-focused application.

### Phase 1: Foundation & Core AI (Nov 2025 – Jan 2026)
- **Objective**: Establish the "Hybrid Shield" architecture.
- **Key Milestones**:
    - Initial FastAPI backend setup with SQLAlchemy.
    - Integration of **MobileBERT** for on-device scam detection.
    - Early Flutter implementation with **Glassmorphism** UI style.
    - Core Permission Wizard for Android SMS hooks.

### Phase 2: UI Overhaul & UX Refinement (Feb 2026)
- **Objective**: Modernize the interface and improve user onboarding.
- **Key Milestones**:
    - **Neo-Brutalist Migration**: Redesigning login, dashboard, and guardian screens with sharp borders and "brutal" shadows.
    - **Language Localisation**: Adding support for 9 regional Indian languages via ML Kit.
    - **Mandatory OTP Flow**: Enforcing secure registration and login sequences to prevent account takeover.
    - **Model Download UI**: Implementing a resilient, polling-based download system for offline detection packs.

### Phase 3: Robustness & Hybrid Expansion (March 2026 – Present)
- **Objective**: Scale the detection accuracy and Guardian safety net.
- **Key Milestones**:
    - **Cloud AI Scaling**: Integrating **Llama 3.3 (70B)** for complex analysis fallback.
    - **TFLite Improvements**: Fixing dynamic tensor shapes and optimizing inference latency for sub-200ms results.
    - **Guardian Alert Refinement**: Fine-tuning the FCM (Firebase Cloud Messaging) triggers for near-instant scam alerts to guardians.
    - **FCM Service Optimization**: Implementing environment-based credential loading for better CI/CD security.

## 2. Key Contributors
The project is primarily driven by two key developers:
- **Atharva Joshi (@Reaper4734)**: Lead for Backend architecture, ML Pipeline training, and TFLite integration. Focused on scalability, model accuracy, and system-level Android hooks.
- **Priyaj Gawade (@priyaj-gawade)**: Lead for Frontend UI/UX and Neo-Brutalist design language. Focused on user-centric features, responsive scaling, and state management using Riverpod.

## 3. Commit Patterns & Best Practices
- **Feature Layering**: Commits often show a clear "feat" for a logic change followed by a "fix" for UI or edge cases, indicating a test-driven or iterative development style.
- **Technical Specification Updates**: The repository maintains a living `detooz_technical_specifications.md`, which is updated alongside major architectural shifts (e.g., the Feb 2026 UI migration).
- **Deployment-Centric**: Frequent "Deploy" commits indicate a robust CI/CD pipeline, likely using the included `deploy.ps1`.

## 4. Notable Repository Milestones
- **Feb 16, 2026**: Transition to offline multilingual detection logic.
- **Feb 22, 2026**: High-volume "Deploy" representing the successful launch of the Neo-Brutalist Phase 1.
- **April 08, 2026**: Refactored registration flow to respect mandatory OTP validation, hardening the app's security posture.
