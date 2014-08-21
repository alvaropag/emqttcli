-record(emqttcli, {emqttcli_id, emqttcli_connection, emqttcli_socket}).

-record(emqttcli_msg, {topic, qos_level, retained, dup, payload}).
