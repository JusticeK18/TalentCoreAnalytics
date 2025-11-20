TalentCoreAnalytics
===================

> A Smart Contract for a **Decentralized Talent Analytics Platform** built on the Clarity blockchain. This platform enables transparent talent assessment, peer endorsements, verifiable work history, and comprehensive analytics using a decentralized reputation scoring system.

* * * * *

🚀 Overview
-----------

The `TalentCoreAnalytics` smart contract implements the core logic for a decentralized application (dApp) designed to manage, verify, and analyze professional talent profiles. By leveraging the **Clarity** smart contract language, the platform ensures that all talent data---including skills, endorsements, and project history---is **transparent, immutable, and verifiable** on the blockchain.

This decentralized approach aims to move beyond traditional, centralized CVs and professional networks, offering a trustless mechanism for employers and peers to assess a talent's real-world expertise and reputation.

### Key Features

-   **Decentralized Profiles:** Talent profiles stored securely on the blockchain.

-   **Verifiable Skills:** Skills can be claimed and verified by the community through endorsements.

-   **Reputation Scoring:** A transparent, calculated score based on endorsements, verified skills, and completed projects.

-   **Peer Endorsements:** Community validation of skills, with endorsements weighted by the endorser's own reputation score.

-   **Project History:** Verifiable record of completed projects, optionally verified by a client/employer.

-   **Advanced Analytics:** A comprehensive function to generate detailed performance metrics and assign a talent tier.

* * * * *

🛠️ Contract Constants & Error Codes
------------------------------------

The contract defines several constants and error codes to manage permissions, thresholds, and operational logic.

### Constants

| Constant Name | Value | Description |
| --- | --- | --- |
| `contract-owner` | `tx-sender` | The address that deployed the contract. |
| `min-endorser-reputation` | `u50` | Minimum reputation score required to endorse a skill. |
| `max-reputation` | `u1000` | The cap for the calculated reputation score. |
| `endorsement-weight` | `u10` | Reputation points gained per endorsement. |
| `skill-verification-weight` | `u25` | Reputation points gained per verified skill (requires 3 endorsements). |
| `project-completion-weight` | `u50` | Reputation points gained per completed project. |
| `platform-fee` | `u100` (micro-STX) | Placeholder for a potential future fee mechanism (currently unused in public functions). |

### Error Codes

| Code | Constant Name | Description |
| --- | --- | --- |
| `u100` | `err-owner-only` | Caller is not the contract owner. |
| `u101` | `err-not-found` | The requested talent or record does not exist. |
| `u102` | `err-already-exists` | A profile, skill, or record already exists. |
| `u103` | `err-unauthorized` | Caller is not authorized for this action. |
| `u104` | `err-invalid-input` | An input value (e.g., proficiency/rating/length) is invalid. |
| `u105` | `err-insufficient-reputation` | Endorser's reputation is below the required threshold (`u50`). |
| `u106` | `err-already-endorsed` | The endorser has already endorsed this talent for this specific skill. |
| `u107` | `err-self-endorsement` | A principal attempted to endorse their own skill. |

* * * * *

💾 Data Structures
------------------

The contract utilizes several maps to store the platform's data, establishing the decentralized profiles and history.

### 🗺️ Maps

| Map Name | Key | Value | Description |
| --- | --- | --- | --- |
| `talent-profiles` | `principal` (Talent Address) | `{ username, bio, reputation-score, total-endorsements, verified-skills-count, projects-completed, registration-block, is-active }` | Stores the primary profile data and calculated reputation metrics. |
| `talent-skills` | `{ talent: principal, skill-id: uint }` | `{ skill-name, proficiency-level, years-experience, is-verified, verification-count, added-block }` | Tracks claimed skills and their verification status for each talent. |
| `endorsements` | `{ endorser: principal, talent: principal, skill-id: uint }` | `{ endorsement-strength, comment, timestamp }` | Records individual skill endorsements given by one principal to another. |
| `project-history` | `{ talent: principal, project-id: uint }` | `{ project-name, role, duration-months, completion-status, rating, verifier: (optional principal) }` | Records a talent's work history and its verification status. |
| `skill-analytics` | `uint` (skill-id) | `{ total-professionals, average-proficiency, total-endorsements, demand-score }` | (Reserved for future aggregation/analytics features; currently unpopulated by contract logic). |

### 🔢 Global Data Variables

| Variable Name | Initial Value | Description |
| --- | --- | --- |
| `total-talents` | `u0` | Total number of registered talent profiles. |
| `total-skills` | `u0` | Total number of unique skill/talent records (not unique skills). |
| `total-endorsements` | `u0` | Total number of endorsements recorded on the platform. |

* * * * *

🔗 Private Functions
--------------------

These helper functions ensure internal contract logic is correct and maintains data integrity.

### `(min-uint (a uint) (b uint))`

-   **Purpose:** Returns the smaller of two unsigned integers.

-   **Role:** Used primarily in the analytics calculation to cap scores at a maximum value.

### `(calculate-reputation-score (endorsement-count uint) (verified-skills uint) (projects uint))`

-   **Purpose:** Calculates a talent's reputation score based on defined weights.

-   **Logic:**

    Reputation=(Endorsements×10)+(Verified Skills×25)+(Projects×50)

    The result is capped at `max-reputation` (`u1000`).

### `(is-valid-proficiency (level uint))`

-   **Purpose:** Ensures a given proficiency level or rating is within the required 1-5 scale.

### `(talent-exists (talent principal))`

-   **Purpose:** Checks if a principal has a registered profile in the `talent-profiles` map.

### `(update-reputation (talent principal))`

-   **Purpose:** Recalculates and updates the `reputation-score` in the `talent-profiles` map for a given talent. This is triggered after any significant event, like an endorsement or project completion.

* * * * *

📝 Public Functions
-------------------

These are the executable functions that users interact with to manage their profiles and history.

### `(register-talent (username (string-ascii 50)) (bio (string-utf8 500)))`

-   **Description:** Allows the transaction sender (`tx-sender`) to create a new, active talent profile.

-   **Pre-conditions:**

    -   Profile must not already exist (`err-already-exists`).

    -   Username must not be empty (`err-invalid-input`).

-   **Post-conditions:** A new profile is created with all counters initialized to `u0`, and `total-talents` is incremented.

### `(add-skill (skill-id uint) (skill-name (string-ascii 100)) (proficiency-level uint) (years-experience uint))`

-   **Description:** Adds a new, claimed skill to the sender's profile.

-   **Pre-conditions:**

    -   Sender must have a profile (`err-not-found`).

    -   `proficiency-level` must be between 1 and 5 (`err-invalid-input`).

    -   The skill/talent combination must not already exist (`err-already-exists`).

-   **Post-conditions:** The skill is added as unverified, and `total-skills` is incremented.

### `(endorse-skill (talent principal) (skill-id uint) (strength uint) (comment (string-utf8 200)))`

-   **Description:** Allows an eligible principal to endorse a specific skill for another talent.

-   **Pre-conditions:**

    -   Endorser and Talent must have profiles (`err-not-found`).

    -   Talent's skill must exist (`err-not-found`).

    -   Endorser cannot endorse their own skill (`err-self-endorsement`).

    -   Endorser must have a minimum reputation of `u50` (`err-insufficient-reputation`).

    -   Endorsement `strength` must be 1-5 (`err-invalid-input`).

    -   Endorser must not have already endorsed this specific skill (`err-already-endorsed`).

-   **Post-conditions:**

    -   Endorsement is recorded.

    -   The skill's `verification-count` is incremented. If the count reaches 3 or more, the skill's `is-verified` status is set to `true`, and the talent's `verified-skills-count` is incremented.

    -   Talent's `total-endorsements` is incremented.

    -   The talent's overall **reputation score is updated**.

    -   `total-endorsements` global variable is incremented.

### `(add-project (project-id uint) (project-name (string-ascii 100)) (role (string-ascii 50)) (duration-months uint) (completion-status bool) (rating uint))`

-   **Description:** Adds a project to the sender's work history.

-   **Pre-conditions:**

    -   Sender must have a profile (`err-not-found`).

    -   `rating` must be 1-5 (`err-invalid-input`).

    -   Project/talent combination must not already exist (`err-already-exists`).

-   **Post-conditions:**

    -   Project is recorded with `verifier: none`.

    -   If `completion-status` is `true`, the talent's `projects-completed` count is incremented, and the **reputation score is updated**.

### `(verify-project (talent principal) (project-id uint))`

-   **Description:** Allows another principal (e.g., client or employer) to vouch for a project's authenticity.

-   **Pre-conditions:**

    -   Verifier must have a profile (`err-not-found`).

    -   Talent and Project must exist (`err-not-found`).

    -   Project must not have an existing verifier (`err-already-exists`).

-   **Post-conditions:**

    -   The verifier's address is recorded in the project history.

    -   The talent's overall **reputation score is updated** (due to a verified project).

### `(generate-comprehensive-talent-analytics (talent principal) (skill-ids (list 10 uint)))`

-   **Description:** A complex, public function designed to provide a deep, weighted analysis and ranking of a talent's profile.

-   **Pre-conditions:**

    -   Talent profile must exist (`err-not-found`).

-   **Calculated Metrics:**

    -   **Skill Diversity Score:** Based on the number of `verified-skills` (capped at 100).

    -   **Endorsement Quality Ratio:** `(total-endorsements * 100) / verified-skills`.

    -   **Project Success Rate:** Currently `u100` if `completed-projects > 0`, otherwise `u0`.

    -   **Activity Score:** A measure of activity (`endorsement-count` + `completed-projects`) relative to `account-age-blocks`.

    -   **Overall Talent Score:** A weighted average of all calculated metrics:

        -   Reputation: **30%**

        -   Skill Diversity: **20%**

        -   Endorsement Quality: **25%**

        -   Project Success Rate: **15%**

        -   Activity Score: **10%**

    -   **Talent Tier:** Categorizes the talent based on the `overall-score`:

        -   `>= 800`: **Elite**

        -   `>= 600`: **Expert**

        -   `>= 400`: **Professional**

        -   `>= 200`: **Intermediate**

        -   `< 200`: **Beginner**

    -   **Percentile Rank:** `(talent-score * 100) / max-reputation`.

-   **Note:** The `skill-ids` input list is currently unused in the calculation logic but is included for potential future integration to analyze specific skill sets.

* * * * *

🔎 Read-Only Functions
----------------------

These functions allow anyone to query the state of the contract without incurring a transaction fee.

| Function Name | Description |
| --- | --- |
| `get-talent-profile` | Returns the profile data for a given principal. |
| `get-talent-skill` | Returns the details of a specific skill for a talent. |
| `get-endorsement` | Returns the details of a specific endorsement between an endorser, talent, and skill. |
| `get-project` | Returns the details of a specific project for a talent. |
| `get-platform-stats` | Returns the global counters for talents, skills, and endorsements. |

* * * * *

📜 MIT License
--------------

A long, professional MIT license is included below for completeness and legal clarity.

```
MIT License

Copyright (c) 2025 TalentCoreAnalytics

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```

* * * * *

🤝 Contribution Guidelines
--------------------------

We welcome contributions to the **TalentCoreAnalytics** smart contract. Your help in improving logic, security, and efficiency is highly valued.

### Reporting Issues

-   If you find any bugs, vulnerabilities, or inconsistencies in the contract logic, please open a detailed issue in the GitHub repository.

-   Include the specific function, the inputs that caused the issue, the expected outcome, and the actual outcome.

### Feature Suggestions

-   For new features or enhancements (e.g., adding a mechanism to decay reputation, improving analytics calculations, implementing the `skill-analytics` map), please open an issue to discuss the proposal before beginning development.

### Code Submissions

1.  **Fork** the repository.

2.  Create a descriptive **branch** for your feature or fix (e.g., `feature/analytics-decay` or `fix/reputation-bug`).

3.  Write your **Clarity code**. Ensure it is clean, commented, and adheres to existing style conventions.

4.  Write **unit tests** using the appropriate Clarity testing framework to cover your changes and prevent regressions.

5.  Create a **Pull Request (PR)** to the `main` branch. Provide a clear summary of your changes and reference the related issue.

### Security

Given the decentralized nature of this platform, **security is paramount**. If you discover a security vulnerability, please **do not** open a public issue. Instead, please follow a responsible disclosure process by contacting the contract owner directly.

* * * * *

🔮 Future Development & Roadmap
-------------------------------

This contract represents a strong foundation for a decentralized talent platform. Future enhancements may include:

-   **Reputation Decay:** Implementing a time-based mechanism to reduce reputation for inactive accounts or very old endorsements.

-   **Dynamic Weighting:** Adjusting `endorsement-weight` based on the endorser's reputation score to give more weight to endorsements from highly reputable principals.

-   **Skill Analytics Aggregation:** Implementing a public function to loop through all `talent-skills` and populate the `skill-analytics` map for marketplace demand analysis.

-   **Token Integration:** Introducing a native platform token for rewards, staking, or governance mechanisms.

-   **Owner Functions:** Adding restricted functions (via `err-owner-only`) for platform maintenance, such as updating constants like `platform-fee`.
