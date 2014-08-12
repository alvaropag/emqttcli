%% Copyright (c) 2013, 2014 Michael Bridgen <mikeb@squaremobius.net>
%% Copyright (c) 2014, Álvaro Pagliari <alvaropag@gmail.com>

%% This file was renamed from types.hrl project erlmqtt 
%% (https://github.com/squaremo/erlmqtt)

%% Permission is hereby granted, free of charge, to any person obtaining a copy
%% of this software and associated documentation files (the "Software"), to deal
%% in the Software without restriction, including without limitation the rights
%% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:

%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.

%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
%% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
%% THE SOFTWARE.

%% Copied from project erlmqtt and renamed on 2014-08-05 license = MIT

-ifndef(emqttcli_types_hrl).
-define(emqttcli_types_hrl, true).

-define(CONNECT, 1).
-define(CONNACK, 2).
-define(PUBLISH, 3).
-define(PUBACK, 4).
-define(PUBREC, 5).
-define(PUBREL, 6).
-define(PUBCOMP, 7).
-define(SUBSCRIBE, 8).
-define(SUBACK, 9).
-define(UNSUBSCRIBE, 10).
-define(UNSUBACK, 11).
-define(PINGREQ, 12).
-define(PINGRESP, 13).
-define(DISCONNECT, 14).

-include("emqttcli_frames.hrl").

%% Represents records that are ready to be serialised. In some cases,
%% records may be constructed with fields left undefined; these must
%% be further constrained here.
-type(mqtt_frame() ::
        #connect{}
      | #connack{}
      | #publish{}
      | #puback{}
      | #pubrec{}
      | #pubrel{}
      | #pubcomp{}
      | #subscribe{ message_id :: message_id() }
      | #suback{}
      | #unsubscribe{ message_id :: message_id() }
      | #unsuback{}
      | 'pingreq'
      | 'pingresp'
      | 'disconnect').

-type(message_type() ::
      ?CONNECT
    | ?CONNACK
    | ?PUBLISH
    | ?PUBACK
    | ?PUBREC
    | ?PUBREL
    | ?PUBCOMP
    | ?SUBSCRIBE
    | ?SUBACK
    | ?UNSUBSCRIBE
    | ?UNSUBACK
    | ?PINGREQ
    | ?PINGRESP
    | ?DISCONNECT).

-type(error() :: {'error', term()}).

-type(qos_level() :: 'at_least_once'
                   | 'at_most_once'
                   | 'exactly_once').

-type(return_code() :: 'ok'
                     | 'wrong_version'
                     | 'bad_id'
                     | 'server_unavailable'
                     | 'bad_auth'
                     | 'not_authorised').

-type(topic() :: iolist() | binary()).
-type(payload() :: iolist() | binary()).

%% This isn't quite adequate: client IDs are supposed to be between 1
%% and 23 characters long; however, Erlang's type notation doesn't let
%% me express that easily.
-type(client_id() :: <<_:8, _:_*8>>).

-type(message_id() :: 1..16#ffff).

-endif.
