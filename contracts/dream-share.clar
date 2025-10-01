;; dream-share
;; Neural interface platform for recording, sharing, and experiencing dreams through brain-computer interfaces
;; Manages dream authentication, sharing permissions, lucid dreaming coordination, and premium payments

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_DREAM_NOT_FOUND (err u101))
(define-constant ERR_INSUFFICIENT_BALANCE (err u102))
(define-constant ERR_INVALID_PRIVACY_LEVEL (err u103))
(define-constant ERR_ALREADY_EXISTS (err u104))
(define-constant ERR_SESSION_FULL (err u105))
(define-constant ERR_INVALID_RATING (err u106))
(define-constant ERR_ALREADY_RATED (err u107))
(define-constant ERR_NOT_SESSION_HOST (err u108))

;; Privacy levels for dream sharing
(define-constant PRIVACY_PUBLIC u0)
(define-constant PRIVACY_FRIENDS u1)
(define-constant PRIVACY_PRIVATE u2)
(define-constant PRIVACY_PREMIUM u3)

;; Dream types for categorization
(define-constant TYPE_LUCID u0)
(define-constant TYPE_NIGHTMARE u1)
(define-constant TYPE_ADVENTURE u2)
(define-constant TYPE_THERAPEUTIC u3)
(define-constant TYPE_CREATIVE u4)

;; Data Variables
(define-data-var next-dream-id uint u1)
(define-data-var next-session-id uint u1)
(define-data-var platform-fee-percentage uint u5) ;; 5% platform fee
(define-data-var total-dreams-recorded uint u0)
(define-data-var total-premium-purchases uint u0)

;; Dream Experience Data Structure
(define-map dreams
    uint ;; dream-id
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        neural-hash: (buff 32), ;; Cryptographic hash of neural data
        dream-type: uint,
        privacy-level: uint,
        price: uint, ;; Price in microSTX for premium dreams
        duration-minutes: uint,
        authenticity-score: uint, ;; Scored 0-100 based on neural verification
        total-ratings: uint,
        rating-sum: uint,
        created-at: uint,
        experience-count: uint, ;; Number of times experienced by others
        is-verified: bool ;; Verified by platform for authenticity
    }
)

;; User Profile Data
(define-map user-profiles
    principal ;; user address
    {
        username: (string-ascii 50),
        total-dreams-created: uint,
        total-dreams-experienced: uint,
        reputation-score: uint, ;; Based on dream quality and ratings
        premium-balance: uint,
        neural-device-verified: bool,
        join-date: uint
    }
)

;; Dream Access Permissions
(define-map dream-access
    {dream-id: uint, user: principal}
    {
        access-granted: bool,
        purchase-price: uint,
        access-date: uint,
        has-rated: bool
    }
)

;; Lucid Dreaming Session Management
(define-map lucid-sessions
    uint ;; session-id
    {
        host: principal,
        title: (string-ascii 100),
        description: (string-ascii 300),
        max-participants: uint,
        current-participants: uint,
        session-price: uint,
        start-time: uint,
        duration-minutes: uint,
        is-active: bool,
        neural-sync-code: (buff 16) ;; Code for neural synchronization
    }
)

;; Session Participants
(define-map session-participants
    {session-id: uint, participant: principal}
    {
        joined-at: uint,
        neural-sync-status: bool,
        experience-rating: uint
    }
)

;; Dream Ratings
(define-map dream-ratings
    {dream-id: uint, rater: principal}
    {
        rating: uint, ;; 1-5 stars
        review: (string-ascii 200),
        rated-at: uint,
        verified-experience: bool
    }
)

;; Revenue tracking for creators
(define-map creator-earnings
    principal
    {
        total-earned: uint,
        dreams-sold: uint,
        sessions-hosted: uint,
        last-withdrawal: uint
    }
)

;; Private Functions

;; Calculate average rating for a dream
(define-private (calculate-average-rating (total-ratings uint) (rating-sum uint))
    (if (> total-ratings u0)
        (/ rating-sum total-ratings)
        u0
    )
)

;; Update user reputation based on dream quality
(define-private (update-user-reputation (user principal) (rating uint))
    (let ((profile (default-to 
                    {username: "", total-dreams-created: u0, total-dreams-experienced: u0, 
                     reputation-score: u50, premium-balance: u0, neural-device-verified: false, join-date: u0}
                    (map-get? user-profiles user))))
        (map-set user-profiles user
            (merge profile {
                reputation-score: (+ (get reputation-score profile) rating)
            })
        )
    )
)

;; Verify neural authenticity (simplified version)
(define-private (verify-neural-authenticity (neural-hash (buff 32)))
    ;; In real implementation, this would verify neural signatures
    ;; For demo purposes, we'll use hash length as a basic check
    (> (len neural-hash) u16)
)

;; Public Functions

;; Initialize user profile
(define-public (create-user-profile (username (string-ascii 50)))
    (let ((existing-profile (map-get? user-profiles tx-sender)))
        (if (is-some existing-profile)
            ERR_ALREADY_EXISTS
            (begin
                (map-set user-profiles tx-sender {
                    username: username,
                    total-dreams-created: u0,
                    total-dreams-experienced: u0,
                    reputation-score: u50, ;; Start with neutral reputation
                    premium-balance: u0,
                    neural-device-verified: false,
                    join-date: block-height
                })
                (ok true)
            )
        )
    )
)

;; Record a new dream experience
(define-public (record-dream 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (neural-hash (buff 32))
    (dream-type uint)
    (privacy-level uint)
    (price uint)
    (duration-minutes uint)
)
    (let ((dream-id (var-get next-dream-id))
          (authenticity-score (if (verify-neural-authenticity neural-hash) u85 u45)))
        (asserts! (<= privacy-level PRIVACY_PREMIUM) ERR_INVALID_PRIVACY_LEVEL)
        (asserts! (<= dream-type TYPE_CREATIVE) ERR_INVALID_PRIVACY_LEVEL)
        
        ;; Create dream record
        (map-set dreams dream-id {
            creator: tx-sender,
            title: title,
            description: description,
            neural-hash: neural-hash,
            dream-type: dream-type,
            privacy-level: privacy-level,
            price: price,
            duration-minutes: duration-minutes,
            authenticity-score: authenticity-score,
            total-ratings: u0,
            rating-sum: u0,
            created-at: block-height,
            experience-count: u0,
            is-verified: (>= authenticity-score u80)
        })
        
        ;; Update user profile
        (let ((profile (default-to 
                        {username: "", total-dreams-created: u0, total-dreams-experienced: u0,
                         reputation-score: u50, premium-balance: u0, neural-device-verified: false, join-date: u0}
                        (map-get? user-profiles tx-sender))))
            (map-set user-profiles tx-sender
                (merge profile {
                    total-dreams-created: (+ (get total-dreams-created profile) u1)
                })
            )
        )
        
        ;; Update global counters
        (var-set next-dream-id (+ dream-id u1))
        (var-set total-dreams-recorded (+ (var-get total-dreams-recorded) u1))
        
        (ok dream-id)
    )
)

;; Purchase access to premium dream
(define-public (purchase-dream-access (dream-id uint))
    (let ((dream-data (unwrap! (map-get? dreams dream-id) ERR_DREAM_NOT_FOUND))
          (user-balance (stx-get-balance tx-sender)))
        
        (asserts! (is-eq (get privacy-level dream-data) PRIVACY_PREMIUM) ERR_NOT_AUTHORIZED)
        (asserts! (>= user-balance (get price dream-data)) ERR_INSUFFICIENT_BALANCE)
        
        ;; Transfer payment
        (let ((platform-fee (/ (* (get price dream-data) (var-get platform-fee-percentage)) u100))
              (creator-payment (- (get price dream-data) platform-fee)))
            
            ;; Pay creator
            (try! (stx-transfer? creator-payment tx-sender (get creator dream-data)))
            
            ;; Pay platform fee to contract owner
            (try! (stx-transfer? platform-fee tx-sender CONTRACT_OWNER))
            
            ;; Grant access
            (map-set dream-access {dream-id: dream-id, user: tx-sender} {
                access-granted: true,
                purchase-price: (get price dream-data),
                access-date: block-height,
                has-rated: false
            })
            
            ;; Update creator earnings
            (let ((earnings (default-to 
                            {total-earned: u0, dreams-sold: u0, sessions-hosted: u0, last-withdrawal: u0}
                            (map-get? creator-earnings (get creator dream-data)))))
                (map-set creator-earnings (get creator dream-data)
                    (merge earnings {
                        total-earned: (+ (get total-earned earnings) creator-payment),
                        dreams-sold: (+ (get dreams-sold earnings) u1)
                    })
                )
            )
            
            ;; Update global counter
            (var-set total-premium-purchases (+ (var-get total-premium-purchases) u1))
            
            (ok true)
        )
    )
)

;; Rate a dream experience
(define-public (rate-dream (dream-id uint) (rating uint) (review (string-ascii 200)))
    (let ((dream-data (unwrap! (map-get? dreams dream-id) ERR_DREAM_NOT_FOUND))
          (access-data (map-get? dream-access {dream-id: dream-id, user: tx-sender})))
        
        (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
        
        ;; Check if user has access or if dream is public
        (asserts! (or 
                    (is-eq (get privacy-level dream-data) PRIVACY_PUBLIC)
                    (and (is-some access-data) (get access-granted (unwrap! access-data ERR_NOT_AUTHORIZED)))
                  ) ERR_NOT_AUTHORIZED)
        
        ;; Check if already rated
        (asserts! (is-none (map-get? dream-ratings {dream-id: dream-id, rater: tx-sender})) ERR_ALREADY_RATED)
        
        ;; Add rating
        (map-set dream-ratings {dream-id: dream-id, rater: tx-sender} {
            rating: rating,
            review: review,
            rated-at: block-height,
            verified-experience: (is-some access-data)
        })
        
        ;; Update dream rating statistics
        (map-set dreams dream-id
            (merge dream-data {
                total-ratings: (+ (get total-ratings dream-data) u1),
                rating-sum: (+ (get rating-sum dream-data) rating)
            })
        )
        
        ;; Update creator reputation
        (update-user-reputation (get creator dream-data) rating)
        
        ;; Mark as rated in access record if exists
        (match access-data
            access-info (map-set dream-access {dream-id: dream-id, user: tx-sender}
                                (merge access-info {has-rated: true}))
            true
        )
        
        (ok true)
    )
)

;; Create lucid dreaming session
(define-public (create-lucid-session
    (title (string-ascii 100))
    (description (string-ascii 300))
    (max-participants uint)
    (session-price uint)
    (duration-minutes uint)
    (neural-sync-code (buff 16))
)
    (let ((session-id (var-get next-session-id)))
        (map-set lucid-sessions session-id {
            host: tx-sender,
            title: title,
            description: description,
            max-participants: max-participants,
            current-participants: u0,
            session-price: session-price,
            start-time: (+ block-height u10), ;; Start in 10 blocks
            duration-minutes: duration-minutes,
            is-active: true,
            neural-sync-code: neural-sync-code
        })
        
        (var-set next-session-id (+ session-id u1))
        (ok session-id)
    )
)

;; Join lucid dreaming session
(define-public (join-lucid-session (session-id uint))
    (let ((session-data (unwrap! (map-get? lucid-sessions session-id) ERR_DREAM_NOT_FOUND))
          (user-balance (stx-get-balance tx-sender)))
        
        (asserts! (get is-active session-data) ERR_NOT_AUTHORIZED)
        (asserts! (< (get current-participants session-data) (get max-participants session-data)) ERR_SESSION_FULL)
        (asserts! (>= user-balance (get session-price session-data)) ERR_INSUFFICIENT_BALANCE)
        
        ;; Pay session fee
        (try! (stx-transfer? (get session-price session-data) tx-sender (get host session-data)))
        
        ;; Add participant
        (map-set session-participants {session-id: session-id, participant: tx-sender} {
            joined-at: block-height,
            neural-sync-status: false,
            experience-rating: u0
        })
        
        ;; Update session participant count
        (map-set lucid-sessions session-id
            (merge session-data {
                current-participants: (+ (get current-participants session-data) u1)
            })
        )
        
        (ok true)
    )
)

;; Read-only functions

;; Get dream details
(define-read-only (get-dream (dream-id uint))
    (map-get? dreams dream-id)
)

;; Get user profile
(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user)
)

;; Get dream rating
(define-read-only (get-dream-rating (dream-id uint))
    (let ((dream-data (map-get? dreams dream-id)))
        (match dream-data
            dream (some (calculate-average-rating (get total-ratings dream) (get rating-sum dream)))
            none
        )
    )
)

;; Get session details
(define-read-only (get-lucid-session (session-id uint))
    (map-get? lucid-sessions session-id)
)

;; Get creator earnings
(define-read-only (get-creator-earnings (creator principal))
    (map-get? creator-earnings creator)
)

;; Get platform statistics
(define-read-only (get-platform-stats)
    (ok {
        total-dreams: (var-get total-dreams-recorded),
        total-premium-purchases: (var-get total-premium-purchases),
        platform-fee: (var-get platform-fee-percentage)
    })
)

