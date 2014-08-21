-record(timer, {timer_ref, keep_alive}).


% connection management
-record(msg_mgmt, {msg_id, reply_to, replay_count = 0, msg}).

