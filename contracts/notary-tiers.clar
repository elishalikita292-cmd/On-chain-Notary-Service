;; Notary Performance Analytics & Tier System
;; Tracks notary metrics and assigns tier-based fee multipliers

(define-constant TIER-BRONZE u0)
(define-constant TIER-SILVER u1)
(define-constant TIER-GOLD u2)
(define-constant TIER-PLATINUM u3)

(define-constant err-unauthorized (err u200))
(define-constant err-invalid-tier (err u201))
(define-constant err-invalid-fee-multiplier (err u202))
(define-constant err-not-authorized-caller (err u204))

(define-data-var admin (optional principal) none)
(define-data-var main-contract (optional principal) none)
(define-map authorized-callers principal bool)

(define-map tier-config uint {
    min-rep: uint,
    min-docs: uint,
    min-accuracy-bps: uint,
    fee-multiplier-bps: uint,
})

(define-map notary-stats principal {
    reputation: uint,
    docs: uint,
    approvals: uint,
    rejections: uint,
    tier: uint,
})

(define-private (default-notary-stats (notary principal))
    (match (map-get? notary-stats notary)
        stats stats
        {
            reputation: u0,
            docs: u0,
            approvals: u0,
            rejections: u0,
            tier: TIER-BRONZE,
        }
    )
)

(define-private (calculate-accuracy-bps (approvals uint) (rejections uint))
    (let ((total (+ approvals rejections)))
        (if (> total u0)
            (/ (* approvals u1000) total)
            u1000
        )
    )
)

(define-private (check-tier-platinum (stats {reputation: uint, docs: uint, approvals: uint, rejections: uint, tier: uint}) (accuracy-bps uint))
    (match (map-get? tier-config TIER-PLATINUM)
        config (if (and (>= (get reputation stats) (get min-rep config)) (>= (get docs stats) (get min-docs config)) (>= accuracy-bps (get min-accuracy-bps config)))
            TIER-PLATINUM
            TIER-GOLD
        )
        TIER-GOLD
    )
)

(define-private (check-tier-gold (stats {reputation: uint, docs: uint, approvals: uint, rejections: uint, tier: uint}) (accuracy-bps uint))
    (match (map-get? tier-config TIER-GOLD)
        config (if (and (>= (get reputation stats) (get min-rep config)) (>= (get docs stats) (get min-docs config)) (>= accuracy-bps (get min-accuracy-bps config)))
            (check-tier-platinum stats accuracy-bps)
            TIER-SILVER
        )
        TIER-SILVER
    )
)

(define-private (check-tier-silver (stats {reputation: uint, docs: uint, approvals: uint, rejections: uint, tier: uint}) (accuracy-bps uint))
    (match (map-get? tier-config TIER-SILVER)
        config (if (and (>= (get reputation stats) (get min-rep config)) (>= (get docs stats) (get min-docs config)) (>= accuracy-bps (get min-accuracy-bps config)))
            (check-tier-gold stats accuracy-bps)
            TIER-BRONZE
        )
        TIER-BRONZE
    )
)

(define-private (compute-tier-from-stats (stats {reputation: uint, docs: uint, approvals: uint, rejections: uint, tier: uint}))
    (let ((accuracy-bps (calculate-accuracy-bps (get approvals stats) (get rejections stats))))
        (check-tier-silver stats accuracy-bps)
    )
)

(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (or (is-none (var-get admin)) (is-eq tx-sender (unwrap! (var-get admin) err-unauthorized)))
            err-unauthorized
        )
        (var-set admin (some new-admin))
        (ok true)
    )
)

(define-public (allow-contract (contract-principal principal))
    (begin
        (asserts! (is-eq tx-sender (unwrap! (var-get admin) err-unauthorized)) err-unauthorized)
        (map-set authorized-callers contract-principal true)
        (ok true)
    )
)

(define-public (revoke-contract (contract-principal principal))
    (begin
        (asserts! (is-eq tx-sender (unwrap! (var-get admin) err-unauthorized)) err-unauthorized)
        (map-delete authorized-callers contract-principal)
        (ok true)
    )
)

(define-public (bootstrap-tier-config)
    (begin
        (asserts! (is-eq tx-sender (unwrap! (var-get admin) err-unauthorized)) err-unauthorized)
        (map-set tier-config TIER-BRONZE {
            min-rep: u0,
            min-docs: u0,
            min-accuracy-bps: u0,
            fee-multiplier-bps: u1000,
        })
        (map-set tier-config TIER-SILVER {
            min-rep: u50,
            min-docs: u25,
            min-accuracy-bps: u900,
            fee-multiplier-bps: u900,
        })
        (map-set tier-config TIER-GOLD {
            min-rep: u150,
            min-docs: u100,
            min-accuracy-bps: u950,
            fee-multiplier-bps: u800,
        })
        (map-set tier-config TIER-PLATINUM {
            min-rep: u300,
            min-docs: u300,
            min-accuracy-bps: u980,
            fee-multiplier-bps: u700,
        })
        (ok true)
    )
)

(define-public (set-tier-config
        (tier uint)
        (min-rep uint)
        (min-docs uint)
        (min-accuracy-bps uint)
        (fee-multiplier-bps uint)
    )
    (begin
        (asserts! (is-eq tx-sender (unwrap! (var-get admin) err-unauthorized)) err-unauthorized)
        (asserts! (<= tier u3) err-invalid-tier)
        (asserts! (and (>= fee-multiplier-bps u100) (<= fee-multiplier-bps u2000)) err-invalid-fee-multiplier)
        (map-set tier-config tier {
            min-rep: min-rep,
            min-docs: min-docs,
            min-accuracy-bps: min-accuracy-bps,
            fee-multiplier-bps: fee-multiplier-bps,
        })
        (ok true)
    )
)

(define-public (record-notarization (notary principal) (approved bool))
    (begin
        (asserts! (is-some (map-get? authorized-callers contract-caller)) err-not-authorized-caller)
        (let ((current-stats (default-notary-stats notary)))
            (map-set notary-stats notary (merge current-stats {
                docs: (+ (get docs current-stats) u1),
                approvals: (if approved (+ (get approvals current-stats) u1) (get approvals current-stats)),
                rejections: (if approved (get rejections current-stats) (+ (get rejections current-stats) u1)),
            }))
            (ok true)
        )
    )
)

(define-public (bump-reputation (notary principal) (increment uint) (decrement uint))
    (begin
        (asserts! (is-some (map-get? authorized-callers contract-caller)) err-not-authorized-caller)
        (let ((current-stats (default-notary-stats notary)))
            (let ((new-rep (if (>= (get reputation current-stats) decrement)
                (- (get reputation current-stats) decrement)
                u0
            )))
                (map-set notary-stats notary (merge current-stats {
                    reputation: (+ new-rep increment),
                }))
                (ok true)
            )
        )
    )
)

(define-public (sync-tier (notary principal))
    (begin
        (asserts! (is-some (map-get? authorized-callers contract-caller)) err-not-authorized-caller)
        (let ((current-stats (default-notary-stats notary)))
            (let ((computed-tier (compute-tier-from-stats current-stats)))
                (map-set notary-stats notary (merge current-stats {
                    tier: computed-tier,
                }))
                (ok computed-tier)
            )
        )
    )
)

(define-read-only (get-notary-tier (notary principal))
    (compute-tier-from-stats (default-notary-stats notary))
)

(define-read-only (get-tier-fee (notary principal) (base-fee uint))
    (let ((tier (compute-tier-from-stats (default-notary-stats notary))))
        (match (map-get? tier-config tier)
            config {
                tier: tier,
                multiplier-bps: (get fee-multiplier-bps config),
                new-fee: (/ (* base-fee (get fee-multiplier-bps config)) u1000),
            }
            {
                tier: TIER-BRONZE,
                multiplier-bps: u1000,
                new-fee: base-fee,
            }
        )
    )
)

(define-read-only (get-tier-thresholds (tier uint))
    (map-get? tier-config tier)
)

(define-read-only (get-notary-stats (notary principal))
    (default-notary-stats notary)
)

(define-read-only (eligible-for-advancement (notary principal))
    (let ((current-tier (compute-tier-from-stats (default-notary-stats notary))))
        (let ((stats (default-notary-stats notary)))
            (if (< current-tier TIER-PLATINUM)
                (let ((next-tier (+ current-tier u1)))
                    (match (map-get? tier-config next-tier)
                        next-config (let ((accuracy-bps (calculate-accuracy-bps (get approvals stats) (get rejections stats))))
                            {
                                current-tier: current-tier,
                                next-tier: (some next-tier),
                                eligible: (and
                                    (>= (get reputation stats) (get min-rep next-config))
                                    (>= (get docs stats) (get min-docs next-config))
                                    (>= accuracy-bps (get min-accuracy-bps next-config))
                                ),
                                rep-needed: (if (>= (get reputation stats) (get min-rep next-config))
                                    u0
                                    (- (get min-rep next-config) (get reputation stats))
                                ),
                                docs-needed: (if (>= (get docs stats) (get min-docs next-config))
                                    u0
                                    (- (get min-docs next-config) (get docs stats))
                                ),
                            }
                        )
                        {
                            current-tier: current-tier,
                            next-tier: (some next-tier),
                            eligible: false,
                            rep-needed: u0,
                            docs-needed: u0,
                        }
                    )
                )
                {
                    current-tier: TIER-PLATINUM,
                    next-tier: none,
                    eligible: true,
                    rep-needed: u0,
                    docs-needed: u0,
                }
            )
        )
    )
)
