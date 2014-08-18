%% Copyright (c) 2013, 2014 Michael Bridgen <mikeb@squaremobius.net>
%% Copyright (c) 2014, Álvaro Pagliari <alvaropag@gmail.com>

%% This file was renamed from frames.hrl project erlmqtt 
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



-ifndef(emqttcli_frames_hrl).
-define(emqttcli_frames_hrl, true).


%% sub-records

-record(will, { topic, % = undefined :: topic(),
                message, % = undefined :: payload(),
                qos = 'at_most_once', % :: qos_level(),
                retain = false :: boolean() }).

-record(subscription, { topic = undefined, % :: topic(),
                        qos = 'at_most_once' % :: qos_level() 
                      }).

-record(qos, { level = 'at_least_once' :: 'at_least_once'
                                       | 'exactly_once',
               message_id = undefined % :: message_id() 
             }).

%% frames

-record(connect, { clean_session = true :: boolean(),
                   will = undefined :: #will{} | 'undefined',
                   username = undefined :: binary() | 'undefined',
                   password = undefined :: binary() | 'undefined',
                   client_id , %= undefined :: client_id(),
                   keep_alive = 0 :: 0..16#ffff }).

-record(connack, {
          return_code %= ok :: return_code() 
         }).

-record(publish, { dup = false :: boolean(),
                   retain = false :: boolean(),
                   qos = 'at_most_once' :: 'at_most_once'
                                          | #qos{},
                   topic = undefined, % :: topic(),
                   payload %= undefined :: payload() 
                 }).

-record(puback, {
          message_id = undefined %:: message_id() 
         }).

-record(pubrec, {
          message_id = undefined %:: message_id() 
         }).

-record(pubrel, {
          dup = false :: boolean(),
          message_id = undefined %:: message_id() 
         }).

-record(pubcomp, {
          message_id = undefined %:: message_id() 
         }).

-record(subscribe, {
          dup = false :: boolean(),
          message_id = undefined, %:: 'undefined' | message_id(),
          subscriptions = undefined :: [#subscription{}] }).

-record(suback, {
          message_id = undefined, % :: message_id(),
          qoses %= undefined :: [qos_level()] 
         }).

-record(unsubscribe, {
          message_id = undefined, % :: 'undefined' | message_id(),
          topics % = [] :: [topic()] 
         }).

-record(unsuback, {
          message_id %= undefined :: message_id() 
         }).

%% pingreq, pingresp and disconnect have no fields, so are represented
%% by atoms

-endif.
