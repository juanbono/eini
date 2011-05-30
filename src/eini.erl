%% Licensed to the Apache Software Foundation (ASF) under one
%% or more contributor license agreements.  See the NOTICE file
%% distributed with this work for additional information
%% regarding copyright ownership.  The ASF licenses this file
%% to you under the Apache License, Version 2.0 (the
%% "License"); you may not use this file except in compliance
%% with the License.  You may obtain a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.

-module(eini).

-author('shino@accense.com').

-export([parse_string/1, parse_file/1]).
%% for debug use
-export([lex/1, parse_tokens/1]).

%% TODO(shino): Add spec's

%% Input:
%%
%% [title1]
%% key = value
%% key2 = value2
%% [title2]
%% key = value
%%
%% Result form:
%%
%% [
%%  {<<"title1">>, [{<<"key">>, <<"value">>},
%%                  {<<"key2">>, <<"value2">>}}],
%%  {<<"title2">>, [{<<"key">>, <<"value">>}]}
%% ].
%%

-type sections() :: [section()].
-type section() :: {Title::binary(), [property()]}.
-type property() :: {Key::binary(), Value::binary()}.

-type reason() :: {illegal_character, Line::integer(), Reason::string()}
                | {syntax_error, Line::integer(), Reason::string()}
                | {duplicate_title, Title::binary()}
                | {duplicate_key, Title::binary(), Key::binary()}.

-spec parse_string(string()) -> {ok, sections()}
                              | {error, reason()}.
parse_string(String) when is_binary(String) ->
  parse_string(binary_to_list(String));
parse_string(String) when is_list(String) ->
  case lex(String) of
    {ok, Tokens} ->
      parse_and_validate(Tokens);
    {error, Reason} ->
      {error, Reason}
  end.

parse_and_validate(Tokens) ->
  case parse_tokens(Tokens) of
    {ok, Parsed} ->
      validate(Parsed);
    {error, Reason} ->
      {error, Reason}
  end.

parse_file(Filename) ->
  case file:read_file(Filename) of
    {ok, Binary} -> parse_string(Binary);
    Error -> Error
  end.

-spec lex(string()) -> {ok, list(Token::tuple())}
                     | {error, {illegal_character, Line::integer(), Reason::string()}}.
lex(String) when is_binary(String) ->
  lex(binary_to_list(String));
lex(String) when is_list(String) ->
  %% Add \n char at the end if does NOT end by \n
  %% TOD(shino): more simple logic?
  String2 = case String of
              "" ->
                "\n";
              _NotEmpty ->
                case lists:last(String) of
                  $\n ->
                    String;
                  _ ->
                    String ++ "\n"
                end
            end,
  case eini_lexer:string(String2) of
    {ok, [{break, _Line}|RestTokens], _EndLine} ->
      {ok, RestTokens};
    {ok, Tokens, _EndLine} ->
      {ok, Tokens};
    {error, {ErrorLine, Mod, Reason}, _EndLine} ->
      {error, {illegal_character, ErrorLine, Mod:format_error(Reason)}}
  end.
  
-spec parse_tokens(Token::tuple()) ->
                      {ok, sections()}
                    | {error, {syntax_error, Line::integer(), Reason::string()}}.
parse_tokens(Tokens) ->
  case eini_parser:parse(Tokens) of
    {ok, Res} ->
      {ok, Res};
    {error, {Line, Mod, Reason}} ->
      {error, {syntax_error, Line, Mod:format_error(Reason)}}
  end.

-spec validate(sections()) ->
                      {ok, sections()}
                    | {error, {duplicate_title, Title::binary()}}
                    | {error, {duplicate_key, Title::binary(), Key::binary()}}.
validate(Parsed) ->
  %% TODO(shino): validate duplicated keys
  {ok, Parsed}.
    
