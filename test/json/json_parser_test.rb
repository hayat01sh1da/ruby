# frozen_string_literal: true
require_relative 'test_helper'
require 'stringio'
require 'tempfile'
begin
  require 'ostruct'
rescue LoadError
end
begin
  require 'bigdecimal'
rescue LoadError
end

class JSONParserTest < Test::Unit::TestCase
  include JSON

  def test_construction
    parser = JSON::Parser.new('test')
    assert_equal 'test', parser.source
  end

  def test_argument_encoding_unmodified
    source = "{}".encode(Encoding::UTF_16)
    JSON::Parser.new(source)
    assert_equal Encoding::UTF_16, source.encoding
  end

  def test_argument_encoding_for_binary_unmodified
    source = "{}".b
    JSON::Parser.new(source)
    assert_equal Encoding::ASCII_8BIT, source.encoding
  end

  def test_error_message_encoding
    bug10705 = '[ruby-core:67386] [Bug #10705]'
    json = ".\"\xE2\x88\x9A\""
    assert_equal(Encoding::UTF_8, json.encoding)
    e = assert_raise(JSON::ParserError) {
      JSON::Ext::Parser.new(json).parse
    }
    assert_equal(Encoding::UTF_8, e.message.encoding, bug10705)
    assert_include(e.message, json, bug10705)
  end

  def test_parsing
    parser = JSON::Parser.new('"test"')
    assert_equal 'test', parser.parse
  end

  def test_parser_reset
    parser = Parser.new('{"a":"b"}')
    assert_equal({ 'a' => 'b' }, parser.parse)
    assert_equal({ 'a' => 'b' }, parser.parse)
  end

  def test_parse_values
    assert_equal(nil,      parse('null'))
    assert_equal(false,    parse('false'))
    assert_equal(true,     parse('true'))
    assert_equal(-23,      parse('-23'))
    assert_equal(23,       parse('23'))
    assert_in_delta(0.23,  parse('0.23'), 1e-2)
    assert_in_delta(0.0,   parse('0e0'), 1e-2)
    assert_equal("",       parse('""'))
    assert_equal("foobar", parse('"foobar"'))
  end

  def test_parse_simple_arrays
    assert_equal([],             parse('[]'))
    assert_equal([],             parse('  [  ] '))
    assert_equal([ nil ],        parse('[null]'))
    assert_equal([ false ],      parse('[false]'))
    assert_equal([ true ],       parse('[true]'))
    assert_equal([ -23 ],        parse('[-23]'))
    assert_equal([ 23 ],         parse('[23]'))
    assert_equal_float([ 0.23 ], parse('[0.23]'))
    assert_equal_float([ 0.0 ],  parse('[0e0]'))
    assert_equal([""],           parse('[""]'))
    assert_equal(["foobar"],     parse('["foobar"]'))
    assert_equal([{}],           parse('[{}]'))
  end

  def test_parse_simple_objects
    assert_equal({}, parse('{}'))
    assert_equal({}, parse(' {   }   '))
    assert_equal({ "a" => nil }, parse('{   "a"   :  null}'))
    assert_equal({ "a" => nil }, parse('{"a":null}'))
    assert_equal({ "a" => false }, parse('{   "a"  :  false  }  '))
    assert_equal({ "a" => false }, parse('{"a":false}'))
    assert_raise(JSON::ParserError) { parse('{false}') }
    assert_equal({ "a" => true }, parse('{"a":true}'))
    assert_equal({ "a" => true }, parse('  { "a" :  true  }   '))
    assert_equal({ "a" => -23 }, parse('  {  "a"  :  -23  }  '))
    assert_equal({ "a" => -23 }, parse('  { "a" : -23 } '))
    assert_equal({ "a" => 23 }, parse('{"a":23  } '))
    assert_equal({ "a" => 23 }, parse('  { "a"  : 23  } '))
    assert_equal({ "a" => 0.23 }, parse(' { "a"  :  0.23 }  '))
    assert_equal({ "a" => 0.23 }, parse('  {  "a"  :  0.23  }  '))
    assert_equal({ "" => 123 }, parse('{"":123}'))
  end

  def test_parse_numbers
    assert_raise(JSON::ParserError) { parse('+23.2') }
    assert_raise(JSON::ParserError) { parse('+23') }
    assert_raise(JSON::ParserError) { parse('.23') }
    assert_raise(JSON::ParserError) { parse('023') }
    assert_raise(JSON::ParserError) { parse('-023') }
    assert_raise(JSON::ParserError) { parse('023.12') }
    assert_raise(JSON::ParserError) { parse('-023.12') }
    assert_raise(JSON::ParserError) { parse('023e12') }
    assert_raise(JSON::ParserError) { parse('-023e12') }
    assert_raise(JSON::ParserError) { parse('-') }
    assert_raise(JSON::ParserError) { parse('-.1') }
    assert_raise(JSON::ParserError) { parse('-e0') }
    assert_equal(23, parse('23'))
    assert_equal(-23, parse('-23'))
    assert_equal_float(3.141, parse('3.141'))
    assert_equal_float(-3.141, parse('-3.141'))
    assert_equal_float(3.141, parse('3141e-3'))
    assert_equal_float(3.141, parse('3141.1e-3'))
    assert_equal_float(3.141, parse('3141E-3'))
    assert_equal_float(3.141, parse('3141.0E-3'))
    assert_equal_float(-3.141, parse('-3141.0e-3'))
    assert_equal_float(-3.141, parse('-3141e-3'))
    assert_raise(ParserError) { parse('NaN') }
    assert parse('NaN', :allow_nan => true).nan?
    assert_raise(ParserError) { parse('Infinity') }
    assert_equal(1.0/0, parse('Infinity', :allow_nan => true))
    assert_raise(ParserError) { parse('-Infinity') }
    assert_equal(-1.0/0, parse('-Infinity', :allow_nan => true))
  end

  def test_parse_bigdecimals
    assert_equal(BigDecimal,                             JSON.parse('{"foo": 9.01234567890123456789}', decimal_class: BigDecimal)["foo"].class)
    assert_equal(BigDecimal("0.901234567890123456789E1"),JSON.parse('{"foo": 9.01234567890123456789}', decimal_class: BigDecimal)["foo"]      )
  end if defined?(::BigDecimal)

  def test_parse_string_mixed_unicode
    assert_equal(["éé"], JSON.parse("[\"\\u00e9é\"]"))
  end

  def test_parse_more_complex_arrays
    a = [ nil, false, true, "foßbar", [ "n€st€d", true ], { "nested" => true, "n€ßt€ð2" => {} }]
    a.permutation.each do |perm|
      json = pretty_generate(perm)
      assert_equal perm, parse(json)
    end
  end

  def test_parse_complex_objects
    a = [ nil, false, true, "foßbar", [ "n€st€d", true ], { "nested" => true, "n€ßt€ð2" => {} }]
    a.permutation.each do |perm|
      s = "a"
      orig_obj = perm.inject({}) { |h, x| h[s.dup] = x; s = s.succ; h }
      json = pretty_generate(orig_obj)
      assert_equal orig_obj, parse(json)
    end
  end

  def test_parse_arrays
    assert_equal([1,2,3], parse('[1,2,3]'))
    assert_equal([1.2,2,3], parse('[1.2,2,3]'))
    assert_equal([[],[[],[]]], parse('[[],[[],[]]]'))
    assert_equal([], parse('[]'))
    assert_equal([], parse('  [  ]  '))
    assert_equal([1], parse('[1]'))
    assert_equal([1], parse('  [ 1  ]  '))
    ary = [[1], ["foo"], [3.14], [4711.0], [2.718], [nil],
      [[1, -2, 3]], [false], [true]]
    assert_equal(ary,
      parse('[[1],["foo"],[3.14],[47.11e+2],[2718.0E-3],[null],[[1,-2,3]],[false],[true]]'))
    assert_equal(ary, parse(%Q{   [   [1] , ["foo"]  ,  [3.14] \t ,  [47.11e+2]\s
      , [2718.0E-3 ],\r[ null] , [[1, -2, 3 ]], [false ],[ true]\n ]  }))
  end

  def test_parse_json_primitive_values
    assert_raise(JSON::ParserError) { parse('') }
    assert_raise(TypeError) { parse(nil) }
    assert_raise(JSON::ParserError) { parse('  /* foo */ ') }
    assert_equal nil, parse('null')
    assert_equal false, parse('false')
    assert_equal true, parse('true')
    assert_equal 23, parse('23')
    assert_equal 1, parse('1')
    assert_equal_float 3.141, parse('3.141'), 1E-3
    assert_equal 2 ** 64, parse('18446744073709551616')
    assert_equal 'foo', parse('"foo"')
    assert parse('NaN', :allow_nan => true).nan?
    assert parse('Infinity', :allow_nan => true).infinite?
    assert parse('-Infinity', :allow_nan => true).infinite?
  end

  def test_parse_arrays_with_allow_trailing_comma
    assert_equal([], parse('[]', allow_trailing_comma: true))
    assert_equal([], parse('[]', allow_trailing_comma: false))
    assert_raise(JSON::ParserError) { parse('[,]', allow_trailing_comma: true) }
    assert_raise(JSON::ParserError) { parse('[,]', allow_trailing_comma: false) }

    assert_equal([1], parse('[1]', allow_trailing_comma: true))
    assert_equal([1], parse('[1]', allow_trailing_comma: false))
    assert_equal([1], parse('[1,]', allow_trailing_comma: true))
    assert_raise(JSON::ParserError) { parse('[1,]', allow_trailing_comma: false) }

    assert_equal([1, 2, 3], parse('[1,2,3]', allow_trailing_comma: true))
    assert_equal([1, 2, 3], parse('[1,2,3]', allow_trailing_comma: false))
    assert_equal([1, 2, 3], parse('[1,2,3,]', allow_trailing_comma: true))
    assert_raise(JSON::ParserError) { parse('[1,2,3,]', allow_trailing_comma: false) }

    assert_equal([1, 2, 3], parse('[  1  ,  2  ,  3  ]', allow_trailing_comma: true))
    assert_equal([1, 2, 3], parse('[  1  ,  2  ,  3  ]', allow_trailing_comma: false))
    assert_equal([1, 2, 3], parse('[  1  ,  2  ,  3  ,  ]', allow_trailing_comma: true))
    assert_raise(JSON::ParserError) { parse('[  1  ,  2  ,  3  ,  ]', allow_trailing_comma: false) }

    assert_equal({'foo' => [1, 2, 3]}, parse('{ "foo": [1,2,3] }', allow_trailing_comma: true))
    assert_equal({'foo' => [1, 2, 3]}, parse('{ "foo": [1,2,3] }', allow_trailing_comma: false))
    assert_equal({'foo' => [1, 2, 3]}, parse('{ "foo": [1,2,3,] }', allow_trailing_comma: true))
    assert_raise(JSON::ParserError) { parse('{ "foo": [1,2,3,] }', allow_trailing_comma: false) }
  end

  def test_parse_object_with_allow_trailing_comma
    assert_equal({}, parse('{}', allow_trailing_comma: true))
    assert_equal({}, parse('{}', allow_trailing_comma: false))
    assert_raise(JSON::ParserError) { parse('{,}', allow_trailing_comma: true) }
    assert_raise(JSON::ParserError) { parse('{,}', allow_trailing_comma: false) }

    assert_equal({'foo'=>'bar'}, parse('{"foo":"bar"}', allow_trailing_comma: true))
    assert_equal({'foo'=>'bar'}, parse('{"foo":"bar"}', allow_trailing_comma: false))
    assert_equal({'foo'=>'bar'}, parse('{"foo":"bar",}', allow_trailing_comma: true))
    assert_raise(JSON::ParserError) { parse('{"foo":"bar",}', allow_trailing_comma: false) }

    assert_equal(
      {'foo'=>'bar', 'baz'=>'qux', 'quux'=>'garply'},
      parse('{"foo":"bar","baz":"qux","quux":"garply"}', allow_trailing_comma: true)
    )
    assert_equal(
      {'foo'=>'bar', 'baz'=>'qux', 'quux'=>'garply'},
      parse('{"foo":"bar","baz":"qux","quux":"garply"}', allow_trailing_comma: false)
    )
    assert_equal(
      {'foo'=>'bar', 'baz'=>'qux', 'quux'=>'garply'},
      parse('{"foo":"bar","baz":"qux","quux":"garply",}', allow_trailing_comma: true)
    )
    assert_raise(JSON::ParserError) {
      parse('{"foo":"bar","baz":"qux","quux":"garply",}', allow_trailing_comma: false)
    }

    assert_equal(
      {'foo'=>'bar', 'baz'=>'qux', 'quux'=>'garply'},
      parse('{  "foo":"bar"  ,  "baz":"qux"  ,  "quux":"garply"  }', allow_trailing_comma: true)
    )
    assert_equal(
      {'foo'=>'bar', 'baz'=>'qux', 'quux'=>'garply'},
      parse('{  "foo":"bar"  ,  "baz":"qux"  ,  "quux":"garply"  }', allow_trailing_comma: false)
    )
    assert_equal(
      {'foo'=>'bar', 'baz'=>'qux', 'quux'=>'garply'},
      parse('{  "foo":"bar"  ,  "baz":"qux"  ,  "quux":"garply"  ,  }', allow_trailing_comma: true)
    )
    assert_raise(JSON::ParserError) {
      parse('{  "foo":"bar"  ,  "baz":"qux"  ,  "quux":"garply"  ,  }', allow_trailing_comma: false)
    }

    assert_equal(
      [{'foo'=>'bar', 'baz'=>'qux', 'quux'=>'garply'}],
      parse('[{"foo":"bar","baz":"qux","quux":"garply"}]', allow_trailing_comma: true)
    )
    assert_equal(
      [{'foo'=>'bar', 'baz'=>'qux', 'quux'=>'garply'}],
      parse('[{"foo":"bar","baz":"qux","quux":"garply"}]', allow_trailing_comma: false)
    )
    assert_equal(
      [{'foo'=>'bar', 'baz'=>'qux', 'quux'=>'garply'}],
      parse('[{"foo":"bar","baz":"qux","quux":"garply",}]', allow_trailing_comma: true)
    )
    assert_raise(JSON::ParserError) {
      parse('[{"foo":"bar","baz":"qux","quux":"garply",}]', allow_trailing_comma: false)
    }
  end

  def test_parse_some_strings
    assert_equal([""], parse('[""]'))
    assert_equal(["\\"], parse('["\\\\"]'))
    assert_equal(['"'], parse('["\""]'))
    assert_equal(['\\"\\'], parse('["\\\\\\"\\\\"]'))
    assert_equal(
      ["\"\b\n\r\t\0\037"],
      parse('["\"\b\n\r\t\u0000\u001f"]')
    )
  end

  if RUBY_ENGINE != "jruby" # https://github.com/ruby/json/issues/138
    def test_parse_broken_string
      s = parse(%{["\x80"]})[0]
      assert_equal("\x80", s)
      assert_equal Encoding::UTF_8, s.encoding
      assert_equal false, s.valid_encoding?

      s = parse(%{["\x80"]}.b)[0]
      assert_equal("\x80", s)
      assert_equal Encoding::UTF_8, s.encoding
      assert_equal false, s.valid_encoding?

      input = %{["\x80"]}.dup.force_encoding(Encoding::US_ASCII)
      assert_raise(Encoding::InvalidByteSequenceError) { parse(input) }
    end
  end

  def test_invalid_unicode_escape
    assert_raise(JSON::ParserError) { parse('"\u"') }
    assert_raise(JSON::ParserError) { parse('"\ua"') }
    assert_raise(JSON::ParserError) { parse('"\uaa"') }
    assert_raise(JSON::ParserError) { parse('"\uaaa"') }
    assert_equal "\uaaaa", parse('"\uaaaa"')

    assert_raise(JSON::ParserError) { parse('"\u______"') }
    assert_raise(JSON::ParserError) { parse('"\u1_____"') }
    assert_raise(JSON::ParserError) { parse('"\u11____"') }
    assert_raise(JSON::ParserError) { parse('"\u111___"') }
  end

  def test_parse_big_integers
    json1 = JSON(orig = (1 << 31) - 1)
    assert_equal orig, parse(json1)
    json2 = JSON(orig = 1 << 31)
    assert_equal orig, parse(json2)
    json3 = JSON(orig = (1 << 62) - 1)
    assert_equal orig, parse(json3)
    json4 = JSON(orig = 1 << 62)
    assert_equal orig, parse(json4)
    json5 = JSON(orig = 1 << 64)
    assert_equal orig, parse(json5)
  end

  def test_parse_duplicate_key
    expected = {"a" => 2}
    expected_sym = {a: 2}

    assert_equal expected, parse('{"a": 1, "a": 2}', allow_duplicate_key: true)
    assert_raise(ParserError) { parse('{"a": 1, "a": 2}', allow_duplicate_key: false) }
    assert_raise(ParserError) { parse('{"a": 1, "a": 2}', allow_duplicate_key: false, symbolize_names: true) }

    assert_deprecated_warning(/duplicate key "a"/) do
      assert_equal expected, parse('{"a": 1, "a": 2}')
    end
    assert_deprecated_warning(/duplicate key "a"/) do
      assert_equal expected_sym, parse('{"a": 1, "a": 2}', symbolize_names: true)
    end

    if RUBY_ENGINE == 'RUBY_ENGINE'
      assert_deprecated_warning(/#{File.basename(__FILE__)}\:#{__LINE__ + 1}/) do
        assert_equal expected, parse('{"a": 1, "a": 2}')
      end
    end

    unless RUBY_ENGINE == 'jruby'
      assert_raise(ParserError) do
        fake_key = Object.new
        JSON.load('{"a": 1, "a": 2}', -> (obj) { obj == "a" ? fake_key : obj }, allow_duplicate_key: false)
      end

      assert_deprecated_warning(/duplicate key #<Object:0x/) do
        fake_key = Object.new
        JSON.load('{"a": 1, "a": 2}', -> (obj) { obj == "a" ? fake_key : obj })
      end
    end
  end

  def test_some_wrong_inputs
    assert_raise(ParserError) { parse('[] bla') }
    assert_raise(ParserError) { parse('[] 1') }
    assert_raise(ParserError) { parse('[] []') }
    assert_raise(ParserError) { parse('[] {}') }
    assert_raise(ParserError) { parse('{} []') }
    assert_raise(ParserError) { parse('{} {}') }
    assert_raise(ParserError) { parse('[NULL]') }
    assert_raise(ParserError) { parse('[FALSE]') }
    assert_raise(ParserError) { parse('[TRUE]') }
    assert_raise(ParserError) { parse('[07]    ') }
    assert_raise(ParserError) { parse('[0a]') }
    assert_raise(ParserError) { parse('[1.]') }
    assert_raise(ParserError) { parse('     ') }
  end

  def test_symbolize_names
    assert_equal({ "foo" => "bar", "baz" => "quux" },
      parse('{"foo":"bar", "baz":"quux"}'))
    assert_equal({ :foo => "bar", :baz => "quux" },
      parse('{"foo":"bar", "baz":"quux"}', :symbolize_names => true))
    assert_raise(ArgumentError) do
      parse('{}', :symbolize_names => true, :create_additions => true)
    end
  end

  def test_freeze
    assert_predicate parse('{}', :freeze => true), :frozen?
    assert_predicate parse('[]', :freeze => true), :frozen?
    assert_predicate parse('"foo"', :freeze => true), :frozen?

    if string_deduplication_available?
      assert_same(-'foo', parse('"foo"', :freeze => true))
      assert_same(-'foo', parse('{"foo": 1}', :freeze => true).keys.first)
    end
  end

  def test_parse_comments
    json = <<~JSON
      {
        "key1":"value1", // eol comment
        "key2":"value2"  /* multi line
                          *  comment */,
        "key3":"value3"  /* multi line
                          // nested eol comment
                          *  comment */
      }
    JSON
    assert_equal(
      { "key1" => "value1", "key2" => "value2", "key3" => "value3" },
      parse(json))
    json = <<~JSON
      {
        "key1":"value1"  /* multi line
                          // nested eol comment
                          /* illegal nested multi line comment */
                          *  comment */
      }
    JSON
    assert_raise(ParserError) { parse(json) }
    json = <<~JSON
      {
        "key1":"value1"  /* multi line
                          // nested eol comment
                          /* legal nested multi line comment start sequence */
      }
    JSON
    assert_equal({ "key1" => "value1" }, parse(json))
    json = <<~JSON
      {
        "key1":"value1"  /* multi line
                         // nested eol comment
                         closed multi comment */
                         and again, throw an Error */
      }
    JSON
    assert_raise(ParserError) { parse(json) }
    json = <<~JSON
      {
        "key1":"value1"  /*/*/
      }
    JSON
    assert_equal({ "key1" => "value1" }, parse(json))
    assert_equal({}, parse('{} /**/'))
    assert_raise(ParserError) { parse('{} /* comment not closed') }
    assert_raise(ParserError) { parse('{} /*/') }
    assert_raise(ParserError) { parse('{} /x wrong comment') }
    assert_raise(ParserError) { parse('{} /') }
  end

  def test_nesting
    too_deep = '[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[["Too deep"]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]'
    too_deep_ary = eval too_deep
    assert_raise(JSON::NestingError) { parse too_deep }
    assert_raise(JSON::NestingError) { parse too_deep, :max_nesting => 100 }
    ok = parse too_deep, :max_nesting => 101
    assert_equal too_deep_ary, ok
    ok = parse too_deep, :max_nesting => nil
    assert_equal too_deep_ary, ok
    ok = parse too_deep, :max_nesting => false
    assert_equal too_deep_ary, ok
    ok = parse too_deep, :max_nesting => 0
    assert_equal too_deep_ary, ok
  end

  def test_backslash
    data = [ '\\.(?i:gif|jpe?g|png)$' ]
    json = '["\\\\.(?i:gif|jpe?g|png)$"]'
    assert_equal data, parse(json)
    #
    data = [ '\\"' ]
    json = '["\\\\\""]'
    assert_equal data, parse(json)
    #
    json = '["/"]'
    data = [ '/' ]
    assert_equal data, parse(json)
    #
    json = '["\""]'
    data = ['"']
    assert_equal data, parse(json)
    #
    json = '["\\\'"]'
    data = ["'"]
    assert_equal data, parse(json)

    json = '["\/"]'
    data = [ '/' ]
    assert_equal data, parse(json)

    data = ['"""""""""""""""""""""""""']
    json = '["\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\"\""]'
    assert_equal data, parse(json)

    data = '["This is a "test" of the emergency broadcast system."]'
    json = "\"[\\\"This is a \\\"test\\\" of the emergency broadcast system.\\\"]\""
    assert_equal data, parse(json)

    data = '\tThis is a test of the emergency broadcast system.'
    json = "\"\\\\tThis is a test of the emergency broadcast system.\""
    assert_equal data, parse(json)

    data = 'This\tis a test of the emergency broadcast system.'
    json = "\"This\\\\tis a test of the emergency broadcast system.\""
    assert_equal data, parse(json)

    data = 'This is\ta test of the emergency broadcast system.'
    json = "\"This is\\\\ta test of the emergency broadcast system.\""
    assert_equal data, parse(json)

    data = 'This is a test of the emergency broadcast\tsystem.'
    json = "\"This is a test of the emergency broadcast\\\\tsystem.\""
    assert_equal data, parse(json)

    data = 'This is a test of the emergency broadcast\tsystem.\n'
    json = "\"This is a test of the emergency broadcast\\\\tsystem.\\\\n\""
    assert_equal data, parse(json)

    data = '"' * 15
    json = "\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\""
    assert_equal data, parse(json)

    data = "\"\"\"\"\"\"\"\"\"\"\"\"\"\"a"
    json = "\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"a\""
    assert_equal data, parse(json)

    data = "\u0001\u0001\u0001\u0001"
    json = "\"\\u0001\\u0001\\u0001\\u0001\""
    assert_equal data, parse(json)

    data = "\u0001a\u0001a\u0001a\u0001a"
    json = "\"\\u0001a\\u0001a\\u0001a\\u0001a\""
    assert_equal data, parse(json)

    data = "\u0001aa\u0001aa"
    json = "\"\\u0001aa\\u0001aa\""
    assert_equal data, parse(json)

    data = "\u0001aa\u0001aa\u0001aa"
    json = "\"\\u0001aa\\u0001aa\\u0001aa\""
    assert_equal data, parse(json)

    data = "\u0001aa\u0001aa\u0001aa\u0001aa\u0001aa\u0001aa"
    json = "\"\\u0001aa\\u0001aa\\u0001aa\\u0001aa\\u0001aa\\u0001aa\""
    assert_equal data, parse(json)

    data = "\u0001a\u0002\u0001a\u0002\u0001a\u0002\u0001a\u0002\u0001a\u0002\u0001a\u0002\u0001a\u0002\u0001a\u0002"
    json = "\"\\u0001a\\u0002\\u0001a\\u0002\\u0001a\\u0002\\u0001a\\u0002\\u0001a\\u0002\\u0001a\\u0002\\u0001a\\u0002\\u0001a\\u0002\""
    assert_equal data, parse(json)

    data = "ab\u0002c"
    json = "\"ab\\u0002c\""
    assert_equal data, parse(json)

    data = "ab\u0002cab\u0002cab\u0002cab\u0002c"
    json = "\"ab\\u0002cab\\u0002cab\\u0002cab\\u0002c\""
    assert_equal data, parse(json)

    data = "ab\u0002cab\u0002cab\u0002cab\u0002cab\u0002cab\u0002c"
    json = "\"ab\\u0002cab\\u0002cab\\u0002cab\\u0002cab\\u0002cab\\u0002c\""
    assert_equal data, parse(json)

    data = "\n\t\f\b\n\t\f\b\n\t\f\b\n\t\f"
    json = "\"\\n\\t\\f\\b\\n\\t\\f\\b\\n\\t\\f\\b\\n\\t\\f\""
    assert_equal data, parse(json)

    data = "\n\t\f\b\n\t\f\b\n\t\f\b\n\t\f\b"
    json = "\"\\n\\t\\f\\b\\n\\t\\f\\b\\n\\t\\f\\b\\n\\t\\f\\b\""
    assert_equal data, parse(json)

    data = "a\n\t\f\b\n\t\f\b\n\t\f\b\n\t"
    json = "\"a\\n\\t\\f\\b\\n\\t\\f\\b\\n\\t\\f\\b\\n\\t\""
    assert_equal data, parse(json)
  end

  class SubArray < Array
    def <<(v)
      @shifted = true
      super
    end

    def shifted?
      @shifted
    end
  end

  class SubArray2 < Array
    def to_json(*a)
      {
        JSON.create_id => self.class.name,
        'ary'          => to_a,
      }.to_json(*a)
    end

    def self.json_create(o)
      o.delete JSON.create_id
      o['ary']
    end
  end

  class SubArrayWrapper
    def initialize
      @data = []
    end

    attr_reader :data

    def [](index)
      @data[index]
    end

    def <<(value)
      @data << value
      @shifted = true
    end

    def shifted?
      @shifted
    end
  end

  def test_parse_array_custom_array_derived_class
    res = parse('[1,2]', :array_class => SubArray)
    assert_equal([1,2], res)
    assert_equal(SubArray, res.class)
    assert res.shifted?
  end

  def test_parse_array_custom_non_array_derived_class
    res = parse('[1,2]', :array_class => SubArrayWrapper)
    assert_equal([1,2], res.data)
    assert_equal(SubArrayWrapper, res.class)
    assert res.shifted?
  end

  def test_parse_object
    assert_equal({}, parse('{}'))
    assert_equal({}, parse('  {  }  '))
    assert_equal({'foo'=>'bar'}, parse('{"foo":"bar"}'))
    assert_equal({'foo'=>'bar'}, parse('    { "foo"  :   "bar"   }   '))
  end

  class SubHash < Hash
    def []=(k, v)
      @item_set = true
      super
    end

    def item_set?
      @item_set
    end
  end

  class SubHash2 < Hash
    def to_json(*a)
      {
        JSON.create_id => self.class.name,
      }.merge(self).to_json(*a)
    end

    def self.json_create(o)
      o.delete JSON.create_id
      self[o]
    end
  end

  def test_parse_object_custom_hash_derived_class
    res = parse('{"foo":"bar"}', :object_class => SubHash)
    assert_equal({"foo" => "bar"}, res)
    assert_equal(SubHash, res.class)
    assert res.item_set?
  end

  if defined?(::OpenStruct)
    class SubOpenStruct < OpenStruct
      def [](k)
        __send__(k)
      end

      def []=(k, v)
        @item_set = true
        __send__("#{k}=", v)
      end

      def item_set?
        @item_set
      end
    end

    def test_parse_object_custom_non_hash_derived_class
      res = parse('{"foo":"bar"}', :object_class => SubOpenStruct)
      assert_equal "bar", res.foo
      assert_equal(SubOpenStruct, res.class)
      assert res.item_set?
    end

    def test_parse_generic_object
      res = parse(
        '{"foo":"bar", "baz":{}}',
        :object_class => JSON::GenericObject
      )
      assert_equal(JSON::GenericObject, res.class)
      assert_equal "bar", res.foo
      assert_equal "bar", res["foo"]
      assert_equal "bar", res[:foo]
      assert_equal "bar", res.to_hash[:foo]
      assert_equal(JSON::GenericObject, res.baz.class)
    end
  end

  def test_generate_core_subclasses_with_new_to_json
    obj = SubHash2["foo" => SubHash2["bar" => true]]
    obj_json = JSON(obj)
    obj_again = parse(obj_json, :create_additions => true)
    assert_kind_of SubHash2, obj_again
    assert_kind_of SubHash2, obj_again['foo']
    assert obj_again['foo']['bar']
    assert_equal obj, obj_again
    assert_equal ["foo"],
      JSON(JSON(SubArray2["foo"]), :create_additions => true)
  end

  def test_generate_core_subclasses_with_default_to_json
    assert_equal '{"foo":"bar"}', JSON(SubHash["foo" => "bar"])
    assert_equal '["foo"]', JSON(SubArray["foo"])
  end

  def test_generate_of_core_subclasses
    obj = SubHash["foo" => SubHash["bar" => true]]
    obj_json = JSON(obj)
    obj_again = JSON(obj_json)
    assert_kind_of Hash, obj_again
    assert_kind_of Hash, obj_again['foo']
    assert obj_again['foo']['bar']
    assert_equal obj, obj_again
  end

  def test_parsing_frozen_ascii8bit_string
    assert_equal(
      { 'foo' => 'bar' },
      JSON('{ "foo": "bar" }'.b.freeze)
    )
  end

  def test_parse_error_message_length
    # Error messages aren't consistent across backends, but we can at least
    # enforce that if they include fragments of the source it should be of
    # reasonable size.
    error = assert_raise(JSON::ParserError) do
      JSON.parse('{"foo": ' + ('A' * 500) + '}')
    end
    assert_operator 80, :>, error.message.bytesize
  end

  def test_parse_error_incomplete_hash
    error = assert_raise(JSON::ParserError) do
      JSON.parse('{"input":{"firstName":"Bob","lastName":"Mob","email":"bob@example.com"}')
    end
    if RUBY_ENGINE == "ruby"
      assert_equal %(expected ',' or '}' after object value, got: EOF at line 1 column 72), error.message
    end
  end

  def test_parse_error_snippet
    omit "C ext only test" unless RUBY_ENGINE == "ruby"

    error = assert_raise(JSON::ParserError) { JSON.parse("あああああああああああああああああああああああ") }
    assert_equal "unexpected character: 'ああああああああああ' at line 1 column 1", error.message

    error = assert_raise(JSON::ParserError) { JSON.parse("aあああああああああああああああああああああああ") }
    assert_equal "unexpected character: 'aああああああああああ' at line 1 column 1", error.message

    error = assert_raise(JSON::ParserError) { JSON.parse("abあああああああああああああああああああああああ") }
    assert_equal "unexpected character: 'abあああああああああ' at line 1 column 1", error.message

    error = assert_raise(JSON::ParserError) { JSON.parse("abcあああああああああああああああああああああああ") }
    assert_equal "unexpected character: 'abcあああああああああ' at line 1 column 1", error.message
  end

  def test_parse_leading_slash
    # ref: https://github.com/ruby/ruby/pull/12598
    assert_raise(JSON::ParserError) do
      JSON.parse("/foo/bar")
    end
  end

  private

  def string_deduplication_available?
    r1 = rand.to_s
    r2 = r1.dup
    begin
      (-r1).equal?(-r2)
    rescue NoMethodError
      false # No String#-@
    end
  end

  def assert_equal_float(expected, actual, delta = 1e-2)
    Array === expected and expected = expected.first
    Array === actual and actual = actual.first
    assert_in_delta(expected, actual, delta)
  end
end
