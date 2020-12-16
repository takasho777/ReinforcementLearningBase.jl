export TicTacToeEnv

struct Nought end
const NOUGHT = Nought()
struct Cross end
const CROSS = Cross()

Base.:!(::Nought) = CROSS
Base.:!(::Cross) = NOUGHT

"""
This is a typical two player, zero sum game. Here we'll also demonstrate how to
implement an environment with multiple state representations.

You might be interested in this [blog](http://www.occasionalenthusiast.com/tag/tic-tac-toe/)
"""
mutable struct TicTacToeEnv <: AbstractEnv
    board::BitArray{3}
    player::Union{Nought,Cross}
end

function TicTacToeEnv()
    board = BitArray{3}(undef, 3, 3, 3)
    fill!(board, false)
    board[:, :, 1] .= true
    TicTacToeEnv(board, CROSS)
end

function reset!(env::TicTacToeEnv)
    fill!(env.board, false)
    env.board[:, :, 1] .= true
    env.player = CROSS
end

struct TicTacToeInfo
    is_terminated::Bool
    winner::Union{Nothing,Nought,Cross}
end

const TIC_TAC_TOE_STATE_INFO = Dict{
    TicTacToeEnv,
    NamedTuple{
        (:index, :is_terminated, :winner),
        Tuple{Int,Bool,Union{Nothing,Nought,Cross}},
    },
}()

Base.hash(env::TicTacToeEnv, h::UInt) = hash(env.board, h)
Base.isequal(a::TicTacToeEnv, b::TicTacToeEnv) = isequal(a.board, b.board)

Base.to_index(::TicTacToeEnv, ::Cross) = 2
Base.to_index(::TicTacToeEnv, ::Nought) = 3

action_space(::TicTacToeEnv) = Base.OneTo(9)

legal_action_space(env::TicTacToeEnv, p) = findall(legal_action_space_mask(env))

function legal_action_space_mask(env::TicTacToeEnv, p)
    if is_win(env, CROSS) || is_win(env, NOUGHT)
        zeros(false, 9)
    else
        vec(view(env.board, :, :, 1))
    end
end

(env::TicTacToeEnv)(action::Int) = env(CartesianIndices((3, 3))[action])

function (env::TicTacToeEnv)(action::CartesianIndex{2})
    env.board[action, 1] = false
    env.board[action, Base.to_index(env, env.player)] = true
    env.player = !env.player
end

current_player(env::TicTacToeEnv) = env.player
players(env::TicTacToeEnv) = (CROSS, NOUGHT)

state(env::TicTacToeEnv, ::Observation{BitArray{3}}, p) = env.board
state_space(env::TicTacToeEnv, ::Observation{BitArray{3}}, p) = Space(fill(false..true, 3, 3, 3))
state(env::TicTacToeEnv, ::Observation{Int}, p) = get_tic_tac_toe_state_info()[env].index
state_space(env::TicTacToeEnv, ::Observation{Int}, p) =
    Base.OneTo(length(get_tic_tac_toe_state_info()))

is_terminated(env::TicTacToeEnv) = get_tic_tac_toe_state_info()[env].is_terminated

function reward(env::TicTacToeEnv, player)
    if is_terminated(env)
        winner = get_tic_tac_toe_state_info()[env].winner
        if isnothing(winner)
            0
        elseif winner === player
            1
        else
            -1
        end
    else
        0
    end
end

function is_win(env::TicTacToeEnv, player)
    b = env.board
    p = Base.to_index(env, player)
    @inbounds begin
        b[1, 1, p] & b[1, 2, p] & b[1, 3, p] ||
            b[2, 1, p] & b[2, 2, p] & b[2, 3, p] ||
            b[3, 1, p] & b[3, 2, p] & b[3, 3, p] ||
            b[1, 1, p] & b[2, 1, p] & b[3, 1, p] ||
            b[1, 2, p] & b[2, 2, p] & b[3, 2, p] ||
            b[1, 3, p] & b[2, 3, p] & b[3, 3, p] ||
            b[1, 1, p] & b[2, 2, p] & b[3, 3, p] ||
            b[1, 3, p] & b[2, 2, p] & b[3, 1, p]
    end
end

function get_tic_tac_toe_state_info()
    if isempty(TIC_TAC_TOE_STATE_INFO)
        @info "initializing state info..."
        t = @elapsed begin
            n = 1
            root = TicTacToeEnv()
            TIC_TAC_TOE_STATE_INFO[root] =
                (index = n, is_terminated = false, winner = nothing)
            walk(root) do env
                if !haskey(TIC_TAC_TOE_STATE_INFO, env)
                    n += 1
                    has_empty_pos = any(view(env.board, :, :, 1))
                    w = if is_win(env, CROSS)
                        CROSS
                    elseif is_win(env, NOUGHT)
                        NOUGHT
                    else
                        nothing
                    end
                    TIC_TAC_TOE_STATE_INFO[env] = (
                        index = n,
                        is_terminated = !(has_empty_pos && isnothing(w)),
                        winner = w,
                    )
                end
            end
        end
        @info "finished initializing state info in $t seconds"
    end
    TIC_TAC_TOE_STATE_INFO
end

NumAgentStyle(::TicTacToeEnv) = MultiAgent(2)
DynamicStyle(::TicTacToeEnv) = SEQUENTIAL
ActionStyle(::TicTacToeEnv) = FULL_ACTION_SET
InformationStyle(::TicTacToeEnv) = PERFECT_INFORMATION
StateStyle(::TicTacToeEnv) = (Observation{Int}(), Observation{BitArray{3}}())
RewardStyle(::TicTacToeEnv) = TERMINAL_REWARD
UtilityStyle(::TicTacToeEnv) = ZERO_SUM
ChanceStyle(::TicTacToeEnv) = DETERMINISTIC