;; Decentralized Talent Analytics Platform
;; A smart contract for managing decentralized talent profiles, skills verification,
;; reputation scoring, and analytics. This platform enables transparent talent assessment,
;; peer endorsements, and verifiable work history on the blockchain.

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-unauthorized (err u103))
(define-constant err-invalid-input (err u104))
(define-constant err-insufficient-reputation (err u105))
(define-constant err-already-endorsed (err u106))
(define-constant err-self-endorsement (err u107))

;; Reputation thresholds
(define-constant min-endorser-reputation u50)
(define-constant max-reputation u1000)
(define-constant endorsement-weight u10)
(define-constant skill-verification-weight u25)
(define-constant project-completion-weight u50)

;; data maps and vars

;; Talent profile storage
(define-map talent-profiles
    principal
    {
        username: (string-ascii 50),
        bio: (string-utf8 500),
        reputation-score: uint,
        total-endorsements: uint,
        verified-skills-count: uint,
        projects-completed: uint,
        registration-block: uint,
        is-active: bool
    }
)

;; Skills registry - maps talent to their claimed skills
(define-map talent-skills
    { talent: principal, skill-id: uint }
    {
        skill-name: (string-ascii 100),
        proficiency-level: uint, ;; 1-5 scale
        years-experience: uint,
        is-verified: bool,
        verification-count: uint,
        added-block: uint
    }
)

;; Endorsements - peer validation of skills
(define-map endorsements
    { endorser: principal, talent: principal, skill-id: uint }
    {
        endorsement-strength: uint, ;; 1-5 scale
        comment: (string-utf8 200),
        timestamp: uint
    }
)

;; Project history for talent
(define-map project-history
    { talent: principal, project-id: uint }
    {
        project-name: (string-ascii 100),
        role: (string-ascii 50),
        duration-months: uint,
        completion-status: bool,
        rating: uint, ;; 1-5 scale
        verifier: (optional principal)
    }
)

;; Analytics aggregation data
(define-map skill-analytics
    uint ;; skill-id
    {
        total-professionals: uint,
        average-proficiency: uint,
        total-endorsements: uint,
        demand-score: uint
    }
)

;; Global counters
(define-data-var total-talents uint u0)
(define-data-var total-skills uint u0)
(define-data-var total-endorsements uint u0)
(define-data-var platform-fee uint u100) ;; in micro-STX

;; private functions

;; Helper function to get minimum of two uints
(define-private (min-uint (a uint) (b uint))
    (if (<= a b) a b)
)

;; Calculate reputation score based on multiple factors
(define-private (calculate-reputation-score (endorsement-count uint) (verified-skills uint) (projects uint))
    (let
        (
            (endorsement-points (* endorsement-count endorsement-weight))
            (skill-points (* verified-skills skill-verification-weight))
            (project-points (* projects project-completion-weight))
            (total-points (+ (+ endorsement-points skill-points) project-points))
        )
        (if (> total-points max-reputation)
            max-reputation
            total-points
        )
    )
)

;; Validate proficiency level (1-5)
(define-private (is-valid-proficiency (level uint))
    (and (>= level u1) (<= level u5))
)

;; Check if talent profile exists
(define-private (talent-exists (talent principal))
    (is-some (map-get? talent-profiles talent))
)

;; Update talent reputation score
(define-private (update-reputation (talent principal))
    (let
        (
            (profile (unwrap! (map-get? talent-profiles talent) false))
            (new-score (calculate-reputation-score 
                (get total-endorsements profile)
                (get verified-skills-count profile)
                (get projects-completed profile)
            ))
        )
        (map-set talent-profiles talent
            (merge profile { reputation-score: new-score })
        )
        true
    )
)

;; public functions

;; Register a new talent profile
(define-public (register-talent (username (string-ascii 50)) (bio (string-utf8 500)))
    (let
        (
            (talent tx-sender)
        )
        (asserts! (not (talent-exists talent)) err-already-exists)
        (asserts! (> (len username) u0) err-invalid-input)
        
        (map-set talent-profiles talent
            {
                username: username,
                bio: bio,
                reputation-score: u0,
                total-endorsements: u0,
                verified-skills-count: u0,
                projects-completed: u0,
                registration-block: block-height,
                is-active: true
            }
        )
        (var-set total-talents (+ (var-get total-talents) u1))
        (ok true)
    )
)

;; Add a skill to talent profile
(define-public (add-skill (skill-id uint) (skill-name (string-ascii 100)) 
                         (proficiency-level uint) (years-experience uint))
    (let
        (
            (talent tx-sender)
        )
        (asserts! (talent-exists talent) err-not-found)
        (asserts! (is-valid-proficiency proficiency-level) err-invalid-input)
        (asserts! (is-none (map-get? talent-skills { talent: talent, skill-id: skill-id })) err-already-exists)
        
        (map-set talent-skills { talent: talent, skill-id: skill-id }
            {
                skill-name: skill-name,
                proficiency-level: proficiency-level,
                years-experience: years-experience,
                is-verified: false,
                verification-count: u0,
                added-block: block-height
            }
        )
        (var-set total-skills (+ (var-get total-skills) u1))
        (ok true)
    )
)

;; Endorse a talent's skill
(define-public (endorse-skill (talent principal) (skill-id uint) 
                              (strength uint) (comment (string-utf8 200)))
    (let
        (
            (endorser tx-sender)
            (endorser-profile (unwrap! (map-get? talent-profiles endorser) err-not-found))
            (talent-profile (unwrap! (map-get? talent-profiles talent) err-not-found))
            (skill (unwrap! (map-get? talent-skills { talent: talent, skill-id: skill-id }) err-not-found))
        )
        (asserts! (not (is-eq endorser talent)) err-self-endorsement)
        (asserts! (>= (get reputation-score endorser-profile) min-endorser-reputation) err-insufficient-reputation)
        (asserts! (is-valid-proficiency strength) err-invalid-input)
        (asserts! (is-none (map-get? endorsements { endorser: endorser, talent: talent, skill-id: skill-id })) 
                  err-already-endorsed)
        
        ;; Record endorsement
        (map-set endorsements { endorser: endorser, talent: talent, skill-id: skill-id }
            {
                endorsement-strength: strength,
                comment: comment,
                timestamp: block-height
            }
        )
        
        ;; Update skill verification count
        (map-set talent-skills { talent: talent, skill-id: skill-id }
            (merge skill { 
                verification-count: (+ (get verification-count skill) u1),
                is-verified: (>= (+ (get verification-count skill) u1) u3)
            })
        )
        
        ;; Update talent profile
        (map-set talent-profiles talent
            (merge talent-profile { 
                total-endorsements: (+ (get total-endorsements talent-profile) u1),
                verified-skills-count: (if (>= (+ (get verification-count skill) u1) u3)
                    (+ (get verified-skills-count talent-profile) u1)
                    (get verified-skills-count talent-profile)
                )
            })
        )
        
        ;; Update reputation
        (update-reputation talent)
        (var-set total-endorsements (+ (var-get total-endorsements) u1))
        (ok true)
    )
)

;; Add project to work history
(define-public (add-project (project-id uint) (project-name (string-ascii 100))
                           (role (string-ascii 50)) (duration-months uint)
                           (completion-status bool) (rating uint))
    (let
        (
            (talent tx-sender)
            (profile (unwrap! (map-get? talent-profiles talent) err-not-found))
        )
        (asserts! (is-valid-proficiency rating) err-invalid-input)
        (asserts! (is-none (map-get? project-history { talent: talent, project-id: project-id })) 
                  err-already-exists)
        
        (map-set project-history { talent: talent, project-id: project-id }
            {
                project-name: project-name,
                role: role,
                duration-months: duration-months,
                completion-status: completion-status,
                rating: rating,
                verifier: none
            }
        )
        
        ;; Update profile if project completed
        (if completion-status
            (begin
                (map-set talent-profiles talent
                    (merge profile { 
                        projects-completed: (+ (get projects-completed profile) u1)
                    })
                )
                (update-reputation talent)
            )
            true
        )
        (ok true)
    )
)

;; Verify a project (by employer/client)
(define-public (verify-project (talent principal) (project-id uint))
    (let
        (
            (verifier tx-sender)
            (project (unwrap! (map-get? project-history { talent: talent, project-id: project-id }) err-not-found))
            (profile (unwrap! (map-get? talent-profiles talent) err-not-found))
        )
        (asserts! (talent-exists verifier) err-not-found)
        (asserts! (is-none (get verifier project)) err-already-exists)
        
        (map-set project-history { talent: talent, project-id: project-id }
            (merge project { verifier: (some verifier) })
        )
        (update-reputation talent)
        (ok true)
    )
)

;; Read-only functions for querying data

(define-read-only (get-talent-profile (talent principal))
    (ok (map-get? talent-profiles talent))
)

(define-read-only (get-talent-skill (talent principal) (skill-id uint))
    (ok (map-get? talent-skills { talent: talent, skill-id: skill-id }))
)

(define-read-only (get-endorsement (endorser principal) (talent principal) (skill-id uint))
    (ok (map-get? endorsements { endorser: endorser, talent: talent, skill-id: skill-id }))
)

(define-read-only (get-project (talent principal) (project-id uint))
    (ok (map-get? project-history { talent: talent, project-id: project-id }))
)

(define-read-only (get-platform-stats)
    (ok {
        total-talents: (var-get total-talents),
        total-skills: (var-get total-skills),
        total-endorsements: (var-get total-endorsements)
    })
)

;; Advanced Analytics Function - Comprehensive Talent Scoring and Ranking System
;; This function provides a detailed analytical assessment of a talent's profile
;; by calculating multiple metrics including skill diversity, endorsement quality,
;; project success rate, and overall platform standing.
(define-public (generate-comprehensive-talent-analytics 
    (talent principal)
    (skill-ids (list 10 uint)))
    (let
        (
            (profile (unwrap! (map-get? talent-profiles talent) err-not-found))
            (reputation (get reputation-score profile))
            (endorsement-count (get total-endorsements profile))
            (verified-skills (get verified-skills-count profile))
            (completed-projects (get projects-completed profile))
            (account-age (- block-height (get registration-block profile)))
            
            ;; Calculate skill diversity score (0-100)
            (skill-diversity-score (if (> verified-skills u0)
                (min-uint u100 (* verified-skills u10))
                u0
            ))
            
            ;; Calculate endorsement quality ratio
            (endorsement-ratio (if (> verified-skills u0)
                (/ (* endorsement-count u100) verified-skills)
                u0
            ))
            
            ;; Calculate project success rate (assuming all completed are successful)
            (project-success-rate (if (> completed-projects u0)
                u100
                u0
            ))
            
            ;; Calculate activity score based on account age and contributions
            (activity-score (if (> account-age u0)
                (min-uint u100 (/ (* (+ endorsement-count completed-projects) u1000) account-age))
                u0
            ))
            
            ;; Calculate overall talent score (weighted average)
            (talent-score (/ 
                (+ 
                    (* reputation u30)
                    (* skill-diversity-score u20)
                    (* (min-uint endorsement-ratio u100) u25)
                    (* project-success-rate u15)
                    (* activity-score u10)
                )
                u100
            ))
            
            ;; Determine talent tier based on score
            (talent-tier (if (>= talent-score u800)
                "Elite"
                (if (>= talent-score u600)
                    "Expert"
                    (if (>= talent-score u400)
                        "Professional"
                        (if (>= talent-score u200)
                            "Intermediate"
                            "Beginner"
                        )
                    )
                )
            ))
        )
        
        ;; Return comprehensive analytics object
        (ok {
            talent-address: talent,
            overall-score: talent-score,
            tier: talent-tier,
            reputation-score: reputation,
            skill-diversity: skill-diversity-score,
            endorsement-quality: endorsement-ratio,
            project-success-rate: project-success-rate,
            activity-score: activity-score,
            total-endorsements: endorsement-count,
            verified-skills: verified-skills,
            completed-projects: completed-projects,
            account-age-blocks: account-age,
            is-active: (get is-active profile),
            percentile-rank: (min-uint u100 (/ (* talent-score u100) max-reputation))
        })
    )
)


