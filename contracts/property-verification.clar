;; Property Verification Contract
;; Validates legitimate real estate assets

(define-data-var contract-owner principal tx-sender)

;; Property data structure
(define-map properties
  { property-id: uint }
  {
    address: (string-utf8 256),
    verified: bool,
    verification-date: uint,
    verified-by: principal,
    property-details-hash: (buff 32)
  }
)

;; List of authorized verifiers
(define-map authorized-verifiers
  { verifier: principal }
  { authorized: bool }
)

;; Initialize contract owner
(define-public (initialize-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u1))
    (ok true)
  )
)

;; Add a verifier
(define-public (add-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u2))
    (map-set authorized-verifiers { verifier: verifier } { authorized: true })
    (ok true)
  )
)

;; Remove a verifier
(define-public (remove-verifier (verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u3))
    (map-set authorized-verifiers { verifier: verifier } { authorized: false })
    (ok true)
  )
)

;; Check if a principal is an authorized verifier
(define-read-only (is-authorized-verifier (verifier principal))
  (default-to false (get authorized (map-get? authorized-verifiers { verifier: verifier })))
)

;; Register a new property
(define-public (register-property
    (property-id uint)
    (address (string-utf8 256))
    (property-details-hash (buff 32)))
  (begin
    (asserts! (is-authorized-verifier tx-sender) (err u4))
    (asserts! (is-none (map-get? properties { property-id: property-id })) (err u5))

    (map-set properties
      { property-id: property-id }
      {
        address: address,
        verified: false,
        verification-date: u0,
        verified-by: tx-sender,
        property-details-hash: property-details-hash
      }
    )
    (ok true)
  )
)

;; Verify a property
(define-public (verify-property (property-id uint))
  (let ((property (map-get? properties { property-id: property-id })))
    (begin
      (asserts! (is-authorized-verifier tx-sender) (err u6))
      (asserts! (is-some property) (err u7))

      (map-set properties
        { property-id: property-id }
        (merge (unwrap-panic property)
          {
            verified: true,
            verification-date: block-height,
            verified-by: tx-sender
          }
        )
      )
      (ok true)
    )
  )
)

;; Get property details
(define-read-only (get-property (property-id uint))
  (map-get? properties { property-id: property-id })
)

;; Check if a property is verified
(define-read-only (is-property-verified (property-id uint))
  (default-to false (get verified (map-get? properties { property-id: property-id })))
)
