;; Fitness Challenge Tracker Smart Contract
;; A decentralized platform for tracking workout challenges and earning fitness rewards

;; Constants
(define-constant MAX_CHALLENGE_CAPACITY u1000000)
(define-constant BASE_WORKOUT_REWARD u10)
(define-constant STREAK_BONUS u2)
(define-constant MAX_STREAK_LEVEL u7)
(define-constant ERR_INVALID_WORKOUT u1)
(define-constant ERR_NO_FITNESS_POINTS u2)
(define-constant ERR_CAPACITY_EXCEEDED u3)
(define-constant BLOCKS_PER_DAY u144)
(define-constant COMMITMENT_MULTIPLIER u2)
(define-constant MIN_COMMITMENT_DURATION u288)
(define-constant EARLY_BREAK_PENALTY u10)

;; Data Variables
(define-data-var total-fitness-points-distributed uint u0)
(define-data-var total-workouts-completed uint u0)
(define-data-var fitness-coordinator principal tx-sender)

;; Data Maps
(define-map athlete-workouts principal uint)
(define-map athlete-fitness-points principal uint)
(define-map workout-start-time principal uint)
(define-map athlete-streak principal uint)
(define-map athlete-last-workout principal uint)
(define-map athlete-committed-points principal uint)
(define-map athlete-commitment-start-block principal uint)

;; Public Functions

(define-public (begin-workout (intensity uint))
  (let
    (
      (athlete tx-sender)
    )
    (asserts! (> intensity u0) (err ERR_INVALID_WORKOUT))
    (map-set workout-start-time athlete burn-block-height)
    (ok true)
  )
)

(define-public (finish-workout (intensity uint))
  (let
    (
      (athlete tx-sender)
      (start-block (default-to u0 (map-get? workout-start-time athlete)))
      (blocks-elapsed (- burn-block-height start-block))
      (last-workout-block (default-to u0 (map-get? athlete-last-workout athlete)))
      (current-streak (default-to u0 (map-get? athlete-streak athlete)))
      (capped-streak (if (<= current-streak MAX_STREAK_LEVEL) current-streak MAX_STREAK_LEVEL))
      (fitness-reward (+ BASE_WORKOUT_REWARD (* capped-streak STREAK_BONUS)))
    )
    (asserts! (and (> start-block u0) (>= blocks-elapsed intensity)) (err ERR_INVALID_WORKOUT))
    (map-set athlete-workouts athlete (+ (default-to u0 (map-get? athlete-workouts athlete)) u1))
    (map-set athlete-fitness-points athlete (+ (default-to u0 (map-get? athlete-fitness-points athlete)) fitness-reward))
    (if (< (- burn-block-height last-workout-block) BLOCKS_PER_DAY)
      (map-set athlete-streak athlete (+ current-streak u1))
      (map-set athlete-streak athlete u1)
    )
    (map-set athlete-last-workout athlete burn-block-height)
    (var-set total-workouts-completed (+ (var-get total-workouts-completed) u1))
    (var-set total-fitness-points-distributed (+ (var-get total-fitness-points-distributed) fitness-reward))
    (asserts! (<= (var-get total-fitness-points-distributed) MAX_CHALLENGE_CAPACITY) (err ERR_CAPACITY_EXCEEDED))
    (ok fitness-reward)
  )
)

(define-public (claim-fitness-rewards)
  (let
    (
      (athlete tx-sender)
      (fitness-balance (default-to u0 (map-get? athlete-fitness-points athlete)))
    )
    (asserts! (> fitness-balance u0) (err ERR_NO_FITNESS_POINTS))
    (map-set athlete-fitness-points athlete u0)
    (ok fitness-balance)
  )
)

;; Commitment Features

(define-public (commit-to-fitness (amount uint))
  (let
    (
      (athlete tx-sender)
    )
    (asserts! (> amount u0) (err ERR_INVALID_WORKOUT))
    (asserts! (>= (var-get total-fitness-points-distributed) amount) (err ERR_CAPACITY_EXCEEDED))
    (map-set athlete-committed-points athlete amount)
    (map-set athlete-commitment-start-block athlete burn-block-height)
    (var-set total-fitness-points-distributed (- (var-get total-fitness-points-distributed) amount))
    (ok amount)
  )
)

(define-public (release-commitment)
  (let
    (
      (athlete tx-sender)
      (committed-amount (default-to u0 (map-get? athlete-committed-points athlete)))
      (commitment-start-block (default-to u0 (map-get? athlete-commitment-start-block athlete)))
      (blocks-committed (- burn-block-height commitment-start-block))
      (penalty (if (< blocks-committed MIN_COMMITMENT_DURATION) (/ (* committed-amount EARLY_BREAK_PENALTY) u100) u0))
      (final-amount (- committed-amount penalty))
    )
    (asserts! (> committed-amount u0) (err ERR_NO_FITNESS_POINTS))
    (map-set athlete-committed-points athlete u0)
    (map-set athlete-commitment-start-block athlete u0)
    (var-set total-fitness-points-distributed (+ (var-get total-fitness-points-distributed) final-amount))
    (ok final-amount)
  )
)

;; Read-Only Functions

(define-read-only (get-workout-count (user principal))
  (default-to u0 (map-get? athlete-workouts user))
)

(define-read-only (get-fitness-balance (user principal))
  (default-to u0 (map-get? athlete-fitness-points user))
)

(define-read-only (get-streak-level (user principal))
  (default-to u0 (map-get? athlete-streak user))
)

(define-read-only (get-fitness-stats)
  {
    total-workouts: (var-get total-workouts-completed),
    total-fitness-points: (var-get total-fitness-points-distributed)
  }
)

;; Private Functions

(define-private (is-fitness-coordinator)
  (is-eq tx-sender (var-get fitness-coordinator))
)
