(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-INPUT (err u400))
(define-constant ERR-INNOVATION-NOT-FOUND (err u404))
(define-constant ERR-PROPOSAL-NOT-FOUND (err u405))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-INNOVATION-CLOSED (err u403))
(define-constant ERR-ALREADY-VOTED (err u406))
(define-constant ERR-DEADLINE-PASSED (err u407))
(define-constant ERR-INVALID-STATUS (err u408))
(define-constant ERR-NOT-RESOLVER (err u409))
(define-constant ERR-ALREADY-RESOLVED (err u410))
(define-constant ERR-INSUFFICIENT-CONSENSUS (err u411))

(define-constant CONTRACT-OWNER tx-sender)

(define-constant STATUS-OPEN u1)
(define-constant STATUS-ANALYZING u2)
(define-constant STATUS-RESOLVED u3)
(define-constant STATUS-IMPLEMENTED u4)
(define-constant STATUS-CLOSED u5)

(define-constant PROPOSAL-PENDING u1)
(define-constant PROPOSAL-APPROVED u2)
(define-constant PROPOSAL-REJECTED u3)
(define-constant PROPOSAL-IMPLEMENTED u4)

(define-constant AI-CONFIDENCE-THRESHOLD u75)
(define-constant CONSENSUS-THRESHOLD u70)
(define-constant MIN-VALIDATORS u3)

(define-data-var innovation-nonce uint u0)
(define-data-var proposal-nonce uint u0)
(define-data-var platform-fee uint u3)
(define-data-var min-innovation-reward uint u20000)
(define-data-var ai-oracle (optional principal) none)

(define-map innovations
  { innovation-id: uint }
  {
    creator: principal,
    title: (string-ascii 120),
    description: (string-ascii 1000),
    domain: (string-ascii 60),
    complexity-level: uint,
    reward-pool: uint,
    deadline: uint,
    created-at: uint,
    status: uint,
    proposal-count: uint,
    selected-proposal: (optional uint),
    ai-analysis: (optional {
      confidence-score: uint,
      feasibility-rating: uint,
      innovation-potential: uint,
      resource-estimate: uint,
      risk-assessment: uint
    }),
    validator-count: uint,
    consensus-score: uint
  }
)

(define-map proposals
  { proposal-id: uint }
  {
    innovation-id: uint,
    proposer: principal,
    title: (string-ascii 120),
    solution-description: (string-ascii 1200),
    technical-approach: (string-ascii 800),
    implementation-timeline: uint,
    resource-requirements: (string-ascii 500),
    expected-outcomes: (string-ascii 600),
    submitted-at: uint,
    status: uint,
    community-votes: uint,
    validator-approvals: uint,
    ai-evaluation: (optional {
      technical-score: uint,
      innovation-score: uint,
      feasibility-score: uint,
      overall-rating: uint
    })
  }
)

(define-map innovation-validators
  { innovation-id: uint, validator: principal }
  {
    assigned-at: uint,
    expertise-match: uint,
    validation-status: uint,
    technical-assessment: (optional uint),
    innovation-assessment: (optional uint)
  }
)

(define-map community-votes
  { proposal-id: uint, voter: principal }
  {
    vote-weight: uint,
    reasoning: (string-ascii 300),
    technical-rating: uint,
    voted-at: uint
  }
)

(define-map resolver-profiles
  { resolver: principal }
  {
    innovations-resolved: uint,
    success-rate: uint,
    expertise-domains: (list 8 (string-ascii 40)),
    reputation-score: uint,
    total-earned: uint,
    ai-collaboration-score: uint
  }
)

(define-map ai-learning-data
  { innovation-id: uint }
  {
    input-features: (list 10 uint),
    outcome-success: bool,
    implementation-time: uint,
    actual-impact: uint,
    lessons-learned: (string-ascii 400)
  }
)

(define-public (register-innovation
  (title (string-ascii 120))
  (description (string-ascii 1000))
  (domain (string-ascii 60))
  (complexity-level uint)
  (reward-pool uint)
  (deadline-blocks uint)
)
  (let
    (
      (innovation-id (+ (var-get innovation-nonce) u1))
      (creator tx-sender)
    )
    (asserts! (>= reward-pool (var-get min-innovation-reward)) ERR-INSUFFICIENT-FUNDS)
    (asserts! (> deadline-blocks u0) ERR-INVALID-INPUT)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u20) ERR-INVALID-INPUT)
    (asserts! (and (<= complexity-level u10) (>= complexity-level u1)) ERR-INVALID-INPUT)
    
    (try! (stx-transfer? reward-pool creator (as-contract tx-sender)))
    
    (map-set innovations
      {innovation-id: innovation-id}
      {
        creator: creator,
        title: title,
        description: description,
        domain: domain,
        complexity-level: complexity-level,
        reward-pool: reward-pool,
        deadline: (+ stacks-block-height deadline-blocks),
        created-at: stacks-block-height,
        status: STATUS-OPEN,
        proposal-count: u0,
        selected-proposal: none,
        ai-analysis: none,
        validator-count: u0,
        consensus-score: u0
      }
    )
    
    (var-set innovation-nonce innovation-id)
    (ok innovation-id)
  )
)

(define-public (submit-proposal
  (innovation-id uint)
  (title (string-ascii 120))
  (solution-description (string-ascii 1200))
  (technical-approach (string-ascii 800))
  (implementation-timeline uint)
  (resource-requirements (string-ascii 500))
  (expected-outcomes (string-ascii 600))
)
  (let
    (
      (proposal-id (+ (var-get proposal-nonce) u1))
      (proposer tx-sender)
      (innovation (unwrap! (map-get? innovations {innovation-id: innovation-id}) ERR-INNOVATION-NOT-FOUND))
    )
    (asserts! (is-eq (get status innovation) STATUS-OPEN) ERR-INNOVATION-CLOSED)
    (asserts! (< stacks-block-height (get deadline innovation)) ERR-DEADLINE-PASSED)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (> (len solution-description) u50) ERR-INVALID-INPUT)
    (asserts! (> implementation-timeline u0) ERR-INVALID-INPUT)
    
    (map-set proposals
      {proposal-id: proposal-id}
      {
        innovation-id: innovation-id,
        proposer: proposer,
        title: title,
        solution-description: solution-description,
        technical-approach: technical-approach,
        implementation-timeline: implementation-timeline,
        resource-requirements: resource-requirements,
        expected-outcomes: expected-outcomes,
        submitted-at: stacks-block-height,
        status: PROPOSAL-PENDING,
        community-votes: u0,
        validator-approvals: u0,
        ai-evaluation: none
      }
    )
    
    (map-set innovations
      {innovation-id: innovation-id}
      (merge innovation {proposal-count: (+ (get proposal-count innovation) u1)})
    )
    
    (let
      (
        (profile (default-to
          {innovations-resolved: u0, success-rate: u100, expertise-domains: (list), reputation-score: u100, total-earned: u0, ai-collaboration-score: u50}
          (map-get? resolver-profiles {resolver: proposer})
        ))
      )
      (map-set resolver-profiles
        {resolver: proposer}
        profile
      )
    )
    
    (var-set proposal-nonce proposal-id)
    (ok proposal-id)
  )
)

(define-public (assign-validators
  (innovation-id uint)
  (validators (list 5 principal))
)
  (let
    (
      (innovation (unwrap! (map-get? innovations {innovation-id: innovation-id}) ERR-INNOVATION-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator innovation)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status innovation) STATUS-OPEN) ERR-INVALID-STATUS)
    (asserts! (>= (len validators) MIN-VALIDATORS) ERR-INVALID-INPUT)
    
    (fold assign-single-validator validators innovation-id)
    
    (map-set innovations
      {innovation-id: innovation-id}
      (merge innovation {
        validator-count: (len validators),
        status: STATUS-ANALYZING
      })
    )
    
    (ok true)
  )
)

(define-private (assign-single-validator (validator principal) (innovation-id uint))
  (begin
    (map-set innovation-validators
      {innovation-id: innovation-id, validator: validator}
      {
        assigned-at: stacks-block-height,
        expertise-match: u80,
        validation-status: u1,
        technical-assessment: none,
        innovation-assessment: none
      }
    )
    innovation-id
  )
)

(define-public (vote-on-proposal
  (proposal-id uint)
  (vote-weight uint)
  (reasoning (string-ascii 300))
  (technical-rating uint)
)
  (let
    (
      (voter tx-sender)
      (proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) ERR-PROPOSAL-NOT-FOUND))
      (innovation (unwrap! (map-get? innovations {innovation-id: (get innovation-id proposal)}) ERR-INNOVATION-NOT-FOUND))
    )
    (asserts! (is-eq (get status innovation) STATUS-ANALYZING) ERR-INVALID-STATUS)
    (asserts! (< stacks-block-height (get deadline innovation)) ERR-DEADLINE-PASSED)
    (asserts! (and (>= vote-weight u1) (<= vote-weight u10)) ERR-INVALID-INPUT)
    (asserts! (<= technical-rating u100) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? community-votes {proposal-id: proposal-id, voter: voter})) ERR-ALREADY-VOTED)
    
    (map-set community-votes
      {proposal-id: proposal-id, voter: voter}
      {
        vote-weight: vote-weight,
        reasoning: reasoning,
        technical-rating: technical-rating,
        voted-at: stacks-block-height
      }
    )
    
    (map-set proposals
      {proposal-id: proposal-id}
      (merge proposal {community-votes: (+ (get community-votes proposal) vote-weight)})
    )
    
    (ok true)
  )
)

(define-public (ai-evaluate-proposal
  (proposal-id uint)
  (technical-score uint)
  (innovation-score uint)
  (feasibility-score uint)
)
  (let
    (
      (proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) ERR-PROPOSAL-NOT-FOUND))
      (ai-oracle-addr (unwrap! (var-get ai-oracle) ERR-NOT-RESOLVER))
    )
    (asserts! (is-eq tx-sender ai-oracle-addr) ERR-NOT-AUTHORIZED)
    (asserts! (<= technical-score u100) ERR-INVALID-INPUT)
    (asserts! (<= innovation-score u100) ERR-INVALID-INPUT)
    (asserts! (<= feasibility-score u100) ERR-INVALID-INPUT)
    
    (let ((overall-rating (/ (+ technical-score innovation-score feasibility-score) u3)))
      (map-set proposals
        {proposal-id: proposal-id}
        (merge proposal {
          ai-evaluation: (some {
            technical-score: technical-score,
            innovation-score: innovation-score,
            feasibility-score: feasibility-score,
            overall-rating: overall-rating
          })
        })
      )
      (ok overall-rating)
    )
  )
)

(define-public (validator-assess-innovation
  (innovation-id uint)
  (technical-assessment uint)
  (innovation-assessment uint)
)
  (let
    (
      (validator tx-sender)
      (validator-info (unwrap! (map-get? innovation-validators {innovation-id: innovation-id, validator: validator}) ERR-NOT-RESOLVER))
    )
    (asserts! (<= technical-assessment u100) ERR-INVALID-INPUT)
    (asserts! (<= innovation-assessment u100) ERR-INVALID-INPUT)
    
    (map-set innovation-validators
      {innovation-id: innovation-id, validator: validator}
      (merge validator-info {
        technical-assessment: (some technical-assessment),
        innovation-assessment: (some innovation-assessment),
        validation-status: u2
      })
    )
    
    (ok true)
  )
)

(define-public (resolve-innovation
  (innovation-id uint)
  (selected-proposal-id uint)
)
  (let
    (
      (innovation (unwrap! (map-get? innovations {innovation-id: innovation-id}) ERR-INNOVATION-NOT-FOUND))
      (proposal (unwrap! (map-get? proposals {proposal-id: selected-proposal-id}) ERR-PROPOSAL-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get creator innovation)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status innovation) STATUS-ANALYZING) ERR-INVALID-STATUS)
    (asserts! (is-eq (get innovation-id proposal) innovation-id) ERR-INVALID-INPUT)
    (asserts! (>= (get community-votes proposal) u10) ERR-INSUFFICIENT-CONSENSUS)
    
    (map-set innovations
      {innovation-id: innovation-id}
      (merge innovation {
        status: STATUS-RESOLVED,
        selected-proposal: (some selected-proposal-id)
      })
    )
    
    (map-set proposals
      {proposal-id: selected-proposal-id}
      (merge proposal {status: PROPOSAL-APPROVED})
    )
    
    (try! (distribute-rewards innovation-id selected-proposal-id))
    
    (ok true)
  )
)

(define-public (implement-solution
  (innovation-id uint)
)
  (let
    (
      (innovation (unwrap! (map-get? innovations {innovation-id: innovation-id}) ERR-INNOVATION-NOT-FOUND))
      (proposal-id (unwrap! (get selected-proposal innovation) ERR-PROPOSAL-NOT-FOUND))
      (proposal (unwrap! (map-get? proposals {proposal-id: proposal-id}) ERR-PROPOSAL-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get proposer proposal)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status innovation) STATUS-RESOLVED) ERR-INVALID-STATUS)
    
    (map-set innovations
      {innovation-id: innovation-id}
      (merge innovation {status: STATUS-IMPLEMENTED})
    )
    
    (map-set proposals
      {proposal-id: proposal-id}
      (merge proposal {status: PROPOSAL-IMPLEMENTED})
    )
    
    (try! (record-learning-data innovation-id))
    
    (ok true)
  )
)

(define-public (update-resolver-expertise
  (resolver principal)
  (expertise-domains (list 8 (string-ascii 40)))
)
  (let
    (
      (profile (default-to
        {innovations-resolved: u0, success-rate: u100, expertise-domains: (list), reputation-score: u100, total-earned: u0, ai-collaboration-score: u50}
        (map-get? resolver-profiles {resolver: resolver})
      ))
    )
    (asserts! (is-eq tx-sender resolver) ERR-NOT-AUTHORIZED)
    
    (map-set resolver-profiles
      {resolver: resolver}
      (merge profile {expertise-domains: expertise-domains})
    )
    
    (ok true)
  )
)

(define-private (distribute-rewards (innovation-id uint) (winning-proposal-id uint))
  (let
    (
      (innovation (unwrap! (map-get? innovations {innovation-id: innovation-id}) ERR-INNOVATION-NOT-FOUND))
      (proposal (unwrap! (map-get? proposals {proposal-id: winning-proposal-id}) ERR-PROPOSAL-NOT-FOUND))
      (total-reward (get reward-pool innovation))
      (platform-fee-amount (/ (* total-reward (var-get platform-fee)) u100))
      (winner-amount (- total-reward platform-fee-amount))
      (winner (get proposer proposal))
    )
    
    (try! (as-contract (stx-transfer? winner-amount tx-sender winner)))
    
    (let
      (
        (profile (default-to
          {innovations-resolved: u0, success-rate: u100, expertise-domains: (list), reputation-score: u100, total-earned: u0, ai-collaboration-score: u50}
          (map-get? resolver-profiles {resolver: winner})
        ))
      )
      (map-set resolver-profiles
        {resolver: winner}
        (merge profile {
          innovations-resolved: (+ (get innovations-resolved profile) u1),
          total-earned: (+ (get total-earned profile) winner-amount),
          reputation-score: (+ (get reputation-score profile) u40),
          ai-collaboration-score: (+ (get ai-collaboration-score profile) u10)
        })
      )
    )
    
    (ok true)
  )
)

(define-private (record-learning-data (innovation-id uint))
  (let
    (
      (innovation (unwrap! (map-get? innovations {innovation-id: innovation-id}) ERR-INNOVATION-NOT-FOUND))
    )
    (map-set ai-learning-data
      {innovation-id: innovation-id}
      {
        input-features: (list (get complexity-level innovation) (get proposal-count innovation) u85 u90 u75 u80 u88 u92 u78 u86),
        outcome-success: true,
        implementation-time: u30,
        actual-impact: u85,
        lessons-learned: "Successful autonomous resolution with high community engagement"
      }
    )
    (ok true)
  )
)

(define-read-only (get-innovation (innovation-id uint))
  (map-get? innovations {innovation-id: innovation-id})
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals {proposal-id: proposal-id})
)

(define-read-only (get-resolver-profile (resolver principal))
  (map-get? resolver-profiles {resolver: resolver})
)

(define-read-only (get-community-vote (proposal-id uint) (voter principal))
  (map-get? community-votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-validator-info (innovation-id uint) (validator principal))
  (map-get? innovation-validators {innovation-id: innovation-id, validator: validator})
)

(define-read-only (get-ai-learning-data (innovation-id uint))
  (map-get? ai-learning-data {innovation-id: innovation-id})
)

(define-read-only (get-platform-stats)
  {
    total-innovations: (var-get innovation-nonce),
    total-proposals: (var-get proposal-nonce),
    platform-fee: (var-get platform-fee),
    min-innovation-reward: (var-get min-innovation-reward),
    ai-oracle: (var-get ai-oracle)
  }
)

(define-public (set-ai-oracle (oracle-address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set ai-oracle (some oracle-address))
    (ok true)
  )
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u15) ERR-INVALID-INPUT)
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-public (set-min-innovation-reward (new-min uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> new-min u0) ERR-INVALID-INPUT)
    (var-set min-innovation-reward new-min)
    (ok true)
  )
)

(begin
  (var-set platform-fee u3)
  (var-set min-innovation-reward u20000)
)