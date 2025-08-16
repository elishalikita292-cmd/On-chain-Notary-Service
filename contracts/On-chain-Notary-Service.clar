(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-document-exists (err u101))
(define-constant err-document-not-found (err u102))
(define-constant err-invalid-hash (err u103))
(define-constant err-unauthorized (err u104))
(define-constant err-invalid-signature (err u105))

(define-map documents
    { hash: (buff 32) }
    {
        notary: principal,
        timestamp: uint,
        block-height: uint,
        signature: (buff 65),
        metadata: (string-utf8 256),
        verified: bool,
        revoked: bool,
    }
)

(define-map notary-registry
    { notary: principal }
    {
        authorized: bool,
        registered-at: uint,
        documents-count: uint,
        reputation-score: uint,
    }
)

(define-map document-revocations
    { hash: (buff 32) }
    {
        revoked-by: principal,
        revoked-at: uint,
        reason: (string-utf8 128),
    }
)

(define-data-var total-documents uint u0)
(define-data-var total-notaries uint u0)
(define-data-var service-fee uint u1000000)

(define-private (is-authorized-notary (notary principal))
    (match (map-get? notary-registry { notary: notary })
        registry-entry (get authorized registry-entry)
        false
    )
)

(define-private (increment-notary-count (notary principal))
    (match (map-get? notary-registry { notary: notary })
        registry-entry (map-set notary-registry { notary: notary }
            (merge registry-entry { documents-count: (+ (get documents-count registry-entry) u1) })
        )
        false
    )
)

(define-private (update-reputation
        (notary principal)
        (points uint)
    )
    (match (map-get? notary-registry { notary: notary })
        registry-entry (map-set notary-registry { notary: notary }
            (merge registry-entry { reputation-score: (+ (get reputation-score registry-entry) points) })
        )
        false
    )
)

(define-public (register-notary)
    (begin
        (asserts! (is-none (map-get? notary-registry { notary: tx-sender }))
            err-document-exists
        )
        (map-set notary-registry { notary: tx-sender } {
            authorized: true,
            registered-at: burn-block-height,
            documents-count: u0,
            reputation-score: u100,
        })
        (var-set total-notaries (+ (var-get total-notaries) u1))
        (ok true)
    )
)

(define-public (revoke-notary (notary principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? notary-registry { notary: notary })
            registry-entry (begin
                (map-set notary-registry { notary: notary }
                    (merge registry-entry { authorized: false })
                )
                (ok true)
            )
            err-document-not-found
        )
    )
)

(define-public (notarize-document
        (document-hash (buff 32))
        (signature (buff 65))
        (metadata (string-utf8 256))
    )
    (begin
        (asserts! (is-authorized-notary tx-sender) err-unauthorized)
        (asserts! (is-none (map-get? documents { hash: document-hash }))
            err-document-exists
        )
        (asserts! (> (len document-hash) u0) err-invalid-hash)
        (try! (stx-transfer? (var-get service-fee) tx-sender contract-owner))
        (map-set documents { hash: document-hash } {
            notary: tx-sender,
            timestamp: burn-block-height,
            block-height: burn-block-height,
            signature: signature,
            metadata: metadata,
            verified: false,
            revoked: false,
        })
        (increment-notary-count tx-sender)
        (var-set total-documents (+ (var-get total-documents) u1))
        (ok document-hash)
    )
)

(define-public (verify-document
        (document-hash (buff 32))
        (verifier-signature (buff 65))
    )
    (match (map-get? documents { hash: document-hash })
        document-entry (begin
            (asserts! (is-authorized-notary tx-sender) err-unauthorized)
            (asserts! (not (get revoked document-entry)) err-document-not-found)
            (map-set documents { hash: document-hash }
                (merge document-entry { verified: true })
            )
            (update-reputation (get notary document-entry) u10)
            (update-reputation tx-sender u5)
            (ok true)
        )
        err-document-not-found
    )
)

(define-public (revoke-document
        (document-hash (buff 32))
        (reason (string-utf8 128))
    )
    (match (map-get? documents { hash: document-hash })
        document-entry (begin
            (asserts!
                (or (is-eq tx-sender (get notary document-entry)) (is-eq tx-sender contract-owner))
                err-unauthorized
            )
            (asserts! (not (get revoked document-entry)) err-document-not-found)
            (map-set documents { hash: document-hash }
                (merge document-entry { revoked: true })
            )
            (map-set document-revocations { hash: document-hash } {
                revoked-by: tx-sender,
                revoked-at: burn-block-height,
                reason: reason,
            })
            (update-reputation (get notary document-entry) (- u20))
            (ok true)
        )
        err-document-not-found
    )
)

(define-public (update-service-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set service-fee new-fee)
        (ok new-fee)
    )
)

(define-read-only (get-document-info (document-hash (buff 32)))
    (map-get? documents { hash: document-hash })
)

(define-read-only (get-notary-info (notary principal))
    (map-get? notary-registry { notary: notary })
)

(define-read-only (get-revocation-info (document-hash (buff 32)))
    (map-get? document-revocations { hash: document-hash })
)

(define-read-only (is-document-valid (document-hash (buff 32)))
    (match (map-get? documents { hash: document-hash })
        document-entry (and
            (not (get revoked document-entry))
            (get verified document-entry)
        )
        false
    )
)

(define-read-only (get-notary-documents-count (notary principal))
    (match (map-get? notary-registry { notary: notary })
        registry-entry (get documents-count registry-entry)
        u0
    )
)

(define-read-only (get-notary-reputation (notary principal))
    (match (map-get? notary-registry { notary: notary })
        registry-entry (get reputation-score registry-entry)
        u0
    )
)

(define-read-only (get-service-fee)
    (var-get service-fee)
)

(define-read-only (get-total-documents)
    (var-get total-documents)
)

(define-read-only (get-total-notaries)
    (var-get total-notaries)
)

(define-read-only (get-contract-owner)
    contract-owner
)

(define-public (verify-document-hash
        (original-data (buff 256))
        (claimed-hash (buff 32))
    )
    (let ((computed-hash (sha256 original-data)))
        (ok (is-eq computed-hash claimed-hash))
    )
)

(define-public (batch-notarize (doc-list (list 10
    {
    hash: (buff 32),
    signature: (buff 65),
    metadata: (string-utf8 256),
})))
    (let ((fee-total (* (var-get service-fee) (len doc-list))))
        (asserts! (is-authorized-notary tx-sender) err-unauthorized)
        (try! (stx-transfer? fee-total tx-sender contract-owner))
        (ok (map process-single-document doc-list))
    )
)

(define-private (process-single-document (doc {
    hash: (buff 32),
    signature: (buff 65),
    metadata: (string-utf8 256),
}))
    (let ((document-hash (get hash doc)))
        (if (is-none (map-get? documents { hash: document-hash }))
            (begin
                (map-set documents { hash: document-hash } {
                    notary: tx-sender,
                    timestamp: burn-block-height,
                    block-height: burn-block-height,
                    signature: (get signature doc),
                    metadata: (get metadata doc),
                    verified: false,
                    revoked: false,
                })
                (increment-notary-count tx-sender)
                (var-set total-documents (+ (var-get total-documents) u1))
                document-hash
            )
            document-hash
        )
    )
)

(define-public (transfer-ownership (new-owner principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok new-owner)
    )
)

(define-read-only (get-document-by-notary
        (notary principal)
        (document-hash (buff 32))
    )
    (match (map-get? documents { hash: document-hash })
        document-entry (if (is-eq (get notary document-entry) notary)
            (some document-entry)
            none
        )
        none
    )
)

(define-read-only (calculate-document-age (document-hash (buff 32)))
    (match (map-get? documents { hash: document-hash })
        document-entry (- burn-block-height (get block-height document-entry))
        u0
    )
)

(define-public (challenge-document
        (document-hash (buff 32))
        (challenge-reason (string-utf8 128))
    )
    (match (map-get? documents { hash: document-hash })
        document-entry (begin
            (asserts! (not (is-eq tx-sender (get notary document-entry)))
                err-unauthorized
            )
            (asserts! (not (get revoked document-entry)) err-document-not-found)
            (update-reputation (get notary document-entry) (- u5))
            (ok true)
        )
        err-document-not-found
    )
)

(define-read-only (get-notary-status (notary principal))
    (match (map-get? notary-registry { notary: notary })
        registry-entry (ok {
            authorized: (get authorized registry-entry),
            registered-at: (get registered-at registry-entry),
            documents-count: (get documents-count registry-entry),
            reputation-score: (get reputation-score registry-entry),
        })
        err-document-not-found
    )
)

(define-public (emergency-revoke-all-by-notary (notary principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some (map-get? notary-registry { notary: notary }))
            err-document-not-found
        )
        (try! (revoke-notary notary))
        (ok true)
    )
)
