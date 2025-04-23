;; Closing Documentation Contract
;; Manages legal transfer requirements

(define-data-var contract-owner principal tx-sender)

;; Document data structure
(define-map closing-documents
  { document-id: uint }
  {
    property-id: uint,
    document-type: (string-utf8 50),
    document-hash: (buff 32),
    submitted-by: principal,
    submission-date: uint,
    verified: bool,
    verified-by: (optional principal),
    verification-date: (optional uint)
  }
)

;; Property closing status
(define-map property-closing-status
  { property-id: uint }
  {
    required-documents: (list 10 (string-utf8 50)),
    all-documents-submitted: bool,
    all-documents-verified: bool,
    closing-complete: bool,
    closing-date: (optional uint)
  }
)

;; List of authorized verifiers
(define-map authorized-verifiers
  { verifier: principal }
  { authorized: bool }
)

;; Counter for document IDs
(define-data-var next-document-id uint u1)

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

;; Initialize property closing requirements
(define-public (initialize-property-closing
    (property-id uint)
    (required-documents (list 10 (string-utf8 50))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u4))
    (asserts! (is-none (map-get? property-closing-status { property-id: property-id })) (err u5))

    (map-set property-closing-status
      { property-id: property-id }
      {
        required-documents: required-documents,
        all-documents-submitted: false,
        all-documents-verified: false,
        closing-complete: false,
        closing-date: none
      }
    )

    (ok true)
  )
)

;; Submit a closing document
(define-public (submit-document
    (property-id uint)
    (document-type (string-utf8 50))
    (document-hash (buff 32)))
  (let (
      (document-id (var-get next-document-id))
      (closing-status (map-get? property-closing-status { property-id: property-id }))
    )
    (begin
      (asserts! (is-some closing-status) (err u6))

      ;; Create the document
      (map-set closing-documents
        { document-id: document-id }
        {
          property-id: property-id,
          document-type: document-type,
          document-hash: document-hash,
          submitted-by: tx-sender,
          submission-date: block-height,
          verified: false,
          verified-by: none,
          verification-date: none
        }
      )

      ;; Increment the document ID counter
      (var-set next-document-id (+ document-id u1))

      (ok document-id)
    )
  )
)

;; Verify a document
(define-public (verify-document (document-id uint))
  (let ((document (map-get? closing-documents { document-id: document-id })))
    (begin
      (asserts! (is-some document) (err u7))
      (asserts! (is-authorized-verifier tx-sender) (err u8))

      (map-set closing-documents
        { document-id: document-id }
        (merge (unwrap-panic document)
          {
            verified: true,
            verified-by: (some tx-sender),
            verification-date: (some block-height)
          }
        )
      )

      (ok true)
    )
  )
)

;; Mark all documents as submitted
(define-public (mark-all-documents-submitted (property-id uint))
  (let ((closing-status (map-get? property-closing-status { property-id: property-id })))
    (begin
      (asserts! (is-some closing-status) (err u9))
      (asserts! (is-authorized-verifier tx-sender) (err u10))

      (map-set property-closing-status
        { property-id: property-id }
        (merge (unwrap-panic closing-status)
          { all-documents-submitted: true }
        )
      )

      (ok true)
    )
  )
)

;; Mark all documents as verified
(define-public (mark-all-documents-verified (property-id uint))
  (let ((closing-status (map-get? property-closing-status { property-id: property-id })))
    (begin
      (asserts! (is-some closing-status) (err u11))
      (asserts! (is-authorized-verifier tx-sender) (err u12))

      (map-set property-closing-status
        { property-id: property-id }
        (merge (unwrap-panic closing-status)
          { all-documents-verified: true }
        )
      )

      (ok true)
    )
  )
)

;; Complete closing
(define-public (complete-closing (property-id uint))
  (let ((closing-status (map-get? property-closing-status { property-id: property-id })))
    (begin
      (asserts! (is-some closing-status) (err u13))
      (asserts! (is-authorized-verifier tx-sender) (err u14))
      (asserts! (get all-documents-submitted (unwrap-panic closing-status)) (err u15))
      (asserts! (get all-documents-verified (unwrap-panic closing-status)) (err u16))

      (map-set property-closing-status
        { property-id: property-id }
        (merge (unwrap-panic closing-status)
          {
            closing-complete: true,
            closing-date: (some block-height)
          }
        )
      )

      (ok true)
    )
  )
)

;; Get document details
(define-read-only (get-document (document-id uint))
  (map-get? closing-documents { document-id: document-id })
)

;; Get property closing status
(define-read-only (get-property-closing-status (property-id uint))
  (map-get? property-closing-status { property-id: property-id })
)

;; Get the next document ID
(define-read-only (get-next-document-id)
  (var-get next-document-id)
)
