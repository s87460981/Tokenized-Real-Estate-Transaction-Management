;; Ownership Tracking Contract
;; Records current and historical title holders

(define-data-var contract-owner principal tx-sender)

;; Property ownership structure
(define-map property-owners
  { property-id: uint }
  { current-owner: principal }
)

;; Ownership history
(define-map ownership-history
  { property-id: uint, index: uint }
  {
    owner: principal,
    acquired-at: uint,
    transaction-id: (buff 32)
  }
)

;; Track the number of ownership transfers per property
(define-map ownership-count
  { property-id: uint }
  { count: uint }
)

;; Initialize contract owner
(define-public (initialize-contract)
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u1))
    (ok true)
  )
)

;; Register initial property ownership
(define-public (register-initial-ownership (property-id uint) (owner principal) (transaction-id (buff 32)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u2))
    (asserts! (is-none (map-get? property-owners { property-id: property-id })) (err u3))

    ;; Set current owner
    (map-set property-owners
      { property-id: property-id }
      { current-owner: owner }
    )

    ;; Record in history
    (map-set ownership-history
      { property-id: property-id, index: u0 }
      {
        owner: owner,
        acquired-at: block-height,
        transaction-id: transaction-id
      }
    )

    ;; Initialize count
    (map-set ownership-count
      { property-id: property-id }
      { count: u1 }
    )

    (ok true)
  )
)

;; Transfer ownership
(define-public (transfer-ownership
    (property-id uint)
    (new-owner principal)
    (transaction-id (buff 32)))
  (let (
      (current-owner-data (map-get? property-owners { property-id: property-id }))
      (count-data (map-get? ownership-count { property-id: property-id }))
    )
    (begin
      (asserts! (is-some current-owner-data) (err u4))
      (asserts! (is-eq (get current-owner (unwrap-panic current-owner-data)) tx-sender) (err u5))
      (asserts! (is-some count-data) (err u6))

      (let ((current-count (get count (unwrap-panic count-data))))
        ;; Update current owner
        (map-set property-owners
          { property-id: property-id }
          { current-owner: new-owner }
        )

        ;; Add to history
        (map-set ownership-history
          { property-id: property-id, index: current-count }
          {
            owner: new-owner,
            acquired-at: block-height,
            transaction-id: transaction-id
          }
        )

        ;; Increment count
        (map-set ownership-count
          { property-id: property-id }
          { count: (+ current-count u1) }
        )

        (ok true)
      )
    )
  )
)

;; Get current owner of a property
(define-read-only (get-current-owner (property-id uint))
  (get current-owner (default-to { current-owner: tx-sender }
    (map-get? property-owners { property-id: property-id })))
)

;; Get ownership history entry
(define-read-only (get-ownership-history-entry (property-id uint) (index uint))
  (map-get? ownership-history { property-id: property-id, index: index })
)

;; Get ownership count
(define-read-only (get-ownership-count (property-id uint))
  (get count (default-to { count: u0 }
    (map-get? ownership-count { property-id: property-id })))
)
