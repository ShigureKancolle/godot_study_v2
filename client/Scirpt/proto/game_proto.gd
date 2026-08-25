#
# BSD 3-Clause License
#
# Copyright (c) 2018 - 2026, Oleg Malyavkin
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# * Neither the name of the copyright holder nor the names of its
#   contributors may be used to endorse or promote products derived from
#   this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# DEBUG_TAB redefine this "  " if you need, example: const DEBUG_TAB = "\t"

const PROTO_VERSION = 3

const DEBUG_TAB : String = "  "

enum PB_ERR {
	NO_ERRORS = 0,
	VARINT_NOT_FOUND = -1,
	REPEATED_COUNT_NOT_FOUND = -2,
	REPEATED_COUNT_MISMATCH = -3,
	LENGTHDEL_SIZE_NOT_FOUND = -4,
	LENGTHDEL_SIZE_MISMATCH = -5,
	PACKAGE_SIZE_MISMATCH = -6,
	UNDEFINED_STATE = -7,
	PARSE_INCOMPLETE = -8,
	REQUIRED_FIELDS = -9
}

enum PB_DATA_TYPE {
	INT32 = 0,
	SINT32 = 1,
	UINT32 = 2,
	INT64 = 3,
	SINT64 = 4,
	UINT64 = 5,
	BOOL = 6,
	ENUM = 7,
	FIXED32 = 8,
	SFIXED32 = 9,
	FLOAT = 10,
	FIXED64 = 11,
	SFIXED64 = 12,
	DOUBLE = 13,
	STRING = 14,
	BYTES = 15,
	MESSAGE = 16,
	MAP = 17
}

const DEFAULT_VALUES_2 = {
	PB_DATA_TYPE.INT32: null,
	PB_DATA_TYPE.SINT32: null,
	PB_DATA_TYPE.UINT32: null,
	PB_DATA_TYPE.INT64: null,
	PB_DATA_TYPE.SINT64: null,
	PB_DATA_TYPE.UINT64: null,
	PB_DATA_TYPE.BOOL: null,
	PB_DATA_TYPE.ENUM: null,
	PB_DATA_TYPE.FIXED32: null,
	PB_DATA_TYPE.SFIXED32: null,
	PB_DATA_TYPE.FLOAT: null,
	PB_DATA_TYPE.FIXED64: null,
	PB_DATA_TYPE.SFIXED64: null,
	PB_DATA_TYPE.DOUBLE: null,
	PB_DATA_TYPE.STRING: null,
	PB_DATA_TYPE.BYTES: null,
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: null
}

const DEFAULT_VALUES_3 = {
	PB_DATA_TYPE.INT32: 0,
	PB_DATA_TYPE.SINT32: 0,
	PB_DATA_TYPE.UINT32: 0,
	PB_DATA_TYPE.INT64: 0,
	PB_DATA_TYPE.SINT64: 0,
	PB_DATA_TYPE.UINT64: 0,
	PB_DATA_TYPE.BOOL: false,
	PB_DATA_TYPE.ENUM: 0,
	PB_DATA_TYPE.FIXED32: 0,
	PB_DATA_TYPE.SFIXED32: 0,
	PB_DATA_TYPE.FLOAT: 0.0,
	PB_DATA_TYPE.FIXED64: 0,
	PB_DATA_TYPE.SFIXED64: 0,
	PB_DATA_TYPE.DOUBLE: 0.0,
	PB_DATA_TYPE.STRING: "",
	PB_DATA_TYPE.BYTES: [],
	PB_DATA_TYPE.MESSAGE: null,
	PB_DATA_TYPE.MAP: []
}

enum PB_TYPE {
	VARINT = 0,
	FIX64 = 1,
	LENGTHDEL = 2,
	STARTGROUP = 3,
	ENDGROUP = 4,
	FIX32 = 5,
	UNDEFINED = 8
}

enum PB_RULE {
	OPTIONAL = 0,
	REQUIRED = 1,
	REPEATED = 2,
	RESERVED = 3
}

enum PB_SERVICE_STATE {
	FILLED = 0,
	UNFILLED = 1
}

class PBField:
	extends RefCounted
	func _init(a_name : String, a_type : int, a_rule : int, a_tag : int, packed : bool, a_value = null):
		name = a_name
		type = a_type
		rule = a_rule
		tag = a_tag
		option_packed = packed
		value = a_value
		
	var name : String
	var type : int
	var rule : int
	var tag : int
	var option_packed : bool
	var value
	var is_map_field : bool = false
	var option_default : bool = false

class PBTypeTag:
	extends RefCounted
	var ok : bool = false
	var type : int
	var tag : int
	var offset : int

class PBServiceField:
	extends RefCounted
	var field : PBField
	var func_ref = null
	var state : int = PB_SERVICE_STATE.UNFILLED

class PBPacker:
	static func convert_signed(n : int) -> int:
		if n < -2147483648:
			return (n << 1) ^ (n >> 63)
		else:
			return (n << 1) ^ (n >> 31)

	static func deconvert_signed(n : int) -> int:
		if n & 0x01:
			return ~(n >> 1)
		else:
			return (n >> 1)

	static func pack_varint(value) -> PackedByteArray:
		var varint : PackedByteArray = PackedByteArray()
		if typeof(value) == TYPE_BOOL:
			if value:
				value = 1
			else:
				value = 0
		for _i in range(9):
			var b = value & 0x7F
			value >>= 7
			if value:
				varint.append(b | 0x80)
			else:
				varint.append(b)
				break
		if varint.size() == 9 && (varint[8] & 0x80 != 0):
			varint.append(0x01)
		return varint

	static func pack_bytes(value, count : int, data_type : int) -> PackedByteArray:
		var bytes : PackedByteArray = PackedByteArray()
		if data_type == PB_DATA_TYPE.FLOAT:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_float(value)
			bytes = spb.get_data_array()
		elif data_type == PB_DATA_TYPE.DOUBLE:
			var spb : StreamPeerBuffer = StreamPeerBuffer.new()
			spb.put_double(value)
			bytes = spb.get_data_array()
		else:
			for _i in range(count):
				bytes.append(value & 0xFF)
				value >>= 8
		return bytes

	static func unpack_bytes(bytes : PackedByteArray, index : int, count : int, data_type : int):
		if data_type == PB_DATA_TYPE.FLOAT:
			return bytes.decode_float(index)
		elif data_type == PB_DATA_TYPE.DOUBLE:
			return bytes.decode_double(index)
		elif data_type == PB_DATA_TYPE.FIXED32:
			return bytes.decode_u32(index)
		elif data_type == PB_DATA_TYPE.SFIXED32:
			return bytes.decode_s32(index)
		elif data_type == PB_DATA_TYPE.FIXED64:
			return bytes.decode_u64(index)
		elif data_type == PB_DATA_TYPE.SFIXED64:
			return bytes.decode_s64(index)
		else:
			var value : int = 0
			for i in range(count):
				value |= bytes[index + i] << (8 * i)
			return value

	static func unpack_varint(varint_bytes) -> int:
		var value : int = 0
		var i: int = varint_bytes.size() - 1
		while i > -1:
			value = (value << 7) | (varint_bytes[i] & 0x7F)
			i -= 1
		return value

	static func pack_type_tag(type : int, tag : int) -> PackedByteArray:
		return pack_varint((tag << 3) | type)

	static func isolate_varint(bytes : PackedByteArray, index : int) -> PackedByteArray:
		var i: int = index
		while i <= index + 10 && i < bytes.size(): # Protobuf varint max size is 10 bytes
			if !(bytes[i] & 0x80):
				return bytes.slice(index, i + 1)
			i += 1
		return [] # Unreachable

	static func unpack_type_tag(bytes : PackedByteArray, index : int) -> PBTypeTag:
		var varint_bytes : PackedByteArray = isolate_varint(bytes, index)
		var result : PBTypeTag = PBTypeTag.new()
		if varint_bytes.size() != 0:
			result.ok = true
			result.offset = varint_bytes.size()
			var unpacked : int = unpack_varint(varint_bytes)
			result.type = unpacked & 0x07
			result.tag = unpacked >> 3
		return result

	static func pack_length_delimeted(type : int, tag : int, bytes : PackedByteArray) -> PackedByteArray:
		var result : PackedByteArray = pack_type_tag(type, tag)
		result.append_array(pack_varint(bytes.size()))
		result.append_array(bytes)
		return result

	static func pb_type_from_data_type(data_type : int) -> int:
		if data_type == PB_DATA_TYPE.INT32 || data_type == PB_DATA_TYPE.SINT32 || data_type == PB_DATA_TYPE.UINT32 || data_type == PB_DATA_TYPE.INT64 || data_type == PB_DATA_TYPE.SINT64 || data_type == PB_DATA_TYPE.UINT64 || data_type == PB_DATA_TYPE.BOOL || data_type == PB_DATA_TYPE.ENUM:
			return PB_TYPE.VARINT
		elif data_type == PB_DATA_TYPE.FIXED32 || data_type == PB_DATA_TYPE.SFIXED32 || data_type == PB_DATA_TYPE.FLOAT:
			return PB_TYPE.FIX32
		elif data_type == PB_DATA_TYPE.FIXED64 || data_type == PB_DATA_TYPE.SFIXED64 || data_type == PB_DATA_TYPE.DOUBLE:
			return PB_TYPE.FIX64
		elif data_type == PB_DATA_TYPE.STRING || data_type == PB_DATA_TYPE.BYTES || data_type == PB_DATA_TYPE.MESSAGE || data_type == PB_DATA_TYPE.MAP:
			return PB_TYPE.LENGTHDEL
		else:
			return PB_TYPE.UNDEFINED

	static func pack_field(field : PBField) -> PackedByteArray:
		var type : int = pb_type_from_data_type(field.type)
		var type_copy : int = type
		if field.rule == PB_RULE.REPEATED && field.option_packed:
			type = PB_TYPE.LENGTHDEL
		var head : PackedByteArray = pack_type_tag(type, field.tag)
		var data : PackedByteArray = PackedByteArray()
		if type == PB_TYPE.VARINT:
			var value
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						value = convert_signed(v)
					else:
						value = v
					data.append_array(pack_varint(value))
				return data
			else:
				if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
					value = convert_signed(field.value)
				else:
					value = field.value
				data = pack_varint(value)
		elif type == PB_TYPE.FIX32:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 4, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 4, field.type))
		elif type == PB_TYPE.FIX64:
			if field.rule == PB_RULE.REPEATED:
				for v in field.value:
					data.append_array(head)
					data.append_array(pack_bytes(v, 8, field.type))
				return data
			else:
				data.append_array(pack_bytes(field.value, 8, field.type))
		elif type == PB_TYPE.LENGTHDEL:
			if field.rule == PB_RULE.REPEATED:
				if type_copy == PB_TYPE.VARINT:
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						var signed_value : int
						for v in field.value:
							signed_value = convert_signed(v)
							data.append_array(pack_varint(signed_value))
					else:
						for v in field.value:
							data.append_array(pack_varint(v))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX32:
					for v in field.value:
						data.append_array(pack_bytes(v, 4, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif type_copy == PB_TYPE.FIX64:
					for v in field.value:
						data.append_array(pack_bytes(v, 8, field.type))
					return pack_length_delimeted(type, field.tag, data)
				elif field.type == PB_DATA_TYPE.STRING:
					for v in field.value:
						var obj = v.to_utf8_buffer()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
				elif field.type == PB_DATA_TYPE.BYTES:
					for v in field.value:
						data.append_array(pack_length_delimeted(type, field.tag, v))
					return data
				elif typeof(field.value[0]) == TYPE_OBJECT:
					for v in field.value:
						var obj : PackedByteArray = v.to_bytes()
						data.append_array(pack_length_delimeted(type, field.tag, obj))
					return data
			else:
				if field.type == PB_DATA_TYPE.STRING:
					var str_bytes : PackedByteArray = field.value.to_utf8_buffer()
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && str_bytes.size() > 0):
						data.append_array(str_bytes)
						return pack_length_delimeted(type, field.tag, data)
				if field.type == PB_DATA_TYPE.BYTES:
					if PROTO_VERSION == 2 || (PROTO_VERSION == 3 && field.value.size() > 0):
						data.append_array(field.value)
						return pack_length_delimeted(type, field.tag, data)
				elif typeof(field.value) == TYPE_OBJECT:
					var obj : PackedByteArray = field.value.to_bytes()
					if obj.size() > 0:
						data.append_array(obj)
					return pack_length_delimeted(type, field.tag, data)
				else:
					pass
		if data.size() > 0:
			head.append_array(data)
			return head
		else:
			return data

	static func skip_unknown_field(bytes : PackedByteArray, offset : int, type : int) -> int:
		if type == PB_TYPE.VARINT:
			return offset + isolate_varint(bytes, offset).size()
		if type == PB_TYPE.FIX64:
			return offset + 8
		if type == PB_TYPE.LENGTHDEL:
			var length_bytes : PackedByteArray = isolate_varint(bytes, offset)
			var length : int = unpack_varint(length_bytes)
			return offset + length_bytes.size() + length
		if type == PB_TYPE.FIX32:
			return offset + 4
		return PB_ERR.UNDEFINED_STATE

	static func unpack_field(bytes : PackedByteArray, offset : int, field : PBField, type : int, message_func_ref) -> int:
		if field.rule == PB_RULE.REPEATED && type != PB_TYPE.LENGTHDEL && field.option_packed:
			var count = isolate_varint(bytes, offset)
			if count.size() > 0:
				offset += count.size()
				count = unpack_varint(count)
				if type == PB_TYPE.VARINT:
					var val
					var counter = offset + count
					while offset < counter:
						val = isolate_varint(bytes, offset)
						if val.size() > 0:
							offset += val.size()
							val = unpack_varint(val)
							if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
								val = deconvert_signed(val)
							elif field.type == PB_DATA_TYPE.BOOL:
								if val:
									val = true
								else:
									val = false
							field.value.append(val)
						else:
							return PB_ERR.REPEATED_COUNT_MISMATCH
					return offset
				elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
					var type_size
					if type == PB_TYPE.FIX32:
						type_size = 4
					else:
						type_size = 8
					var val
					var counter = offset + count
					while offset < counter:
						if (offset + type_size) > bytes.size():
							return PB_ERR.REPEATED_COUNT_MISMATCH
						val = unpack_bytes(bytes, offset, type_size, field.type)
						offset += type_size
						field.value.append(val)
					return offset
			else:
				return PB_ERR.REPEATED_COUNT_NOT_FOUND
		else:
			if type == PB_TYPE.VARINT:
				var val = isolate_varint(bytes, offset)
				if val.size() > 0:
					offset += val.size()
					val = unpack_varint(val)
					if field.type == PB_DATA_TYPE.SINT32 || field.type == PB_DATA_TYPE.SINT64:
						val = deconvert_signed(val)
					elif field.type == PB_DATA_TYPE.BOOL:
						if val:
							val = true
						else:
							val = false
					if field.rule == PB_RULE.REPEATED:
						field.value.append(val)
					else:
						field.value = val
				else:
					return PB_ERR.VARINT_NOT_FOUND
				return offset
			elif type == PB_TYPE.FIX32 || type == PB_TYPE.FIX64:
				var type_size
				if type == PB_TYPE.FIX32:
					type_size = 4
				else:
					type_size = 8
				var val
				if (offset + type_size) > bytes.size():
					return PB_ERR.REPEATED_COUNT_MISMATCH
				val = unpack_bytes(bytes, offset, type_size, field.type)
				offset += type_size
				if field.rule == PB_RULE.REPEATED:
					field.value.append(val)
				else:
					field.value = val
				return offset
			elif type == PB_TYPE.LENGTHDEL:
				var inner_size = isolate_varint(bytes, offset)
				if inner_size.size() > 0:
					offset += inner_size.size()
					inner_size = unpack_varint(inner_size)
					if inner_size >= 0:
						if inner_size + offset > bytes.size():
							return PB_ERR.LENGTHDEL_SIZE_MISMATCH
						if message_func_ref != null:
							var message = message_func_ref.call()
							if inner_size > 0:
								var sub_offset = message.from_bytes(bytes, offset, inner_size + offset)
								if sub_offset > 0:
									if sub_offset - offset >= inner_size:
										offset = sub_offset
										return offset
									else:
										return PB_ERR.LENGTHDEL_SIZE_MISMATCH
								return sub_offset
							else:
								return offset
						elif field.type == PB_DATA_TYPE.STRING:
							var str_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(str_bytes.get_string_from_utf8())
							else:
								field.value = str_bytes.get_string_from_utf8()
							return offset + inner_size
						elif field.type == PB_DATA_TYPE.BYTES:
							var val_bytes : PackedByteArray = bytes.slice(offset, inner_size + offset)
							if field.rule == PB_RULE.REPEATED:
								field.value.append(val_bytes)
							else:
								field.value = val_bytes
							return offset + inner_size
					else:
						return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
				else:
					return PB_ERR.LENGTHDEL_SIZE_NOT_FOUND
		return PB_ERR.UNDEFINED_STATE

	static func unpack_message(data, bytes : PackedByteArray, offset : int, limit : int) -> int:
		while true:
			var tt : PBTypeTag = unpack_type_tag(bytes, offset)
			if tt.ok:
				offset += tt.offset
				if data.has(tt.tag):
					var service : PBServiceField = data[tt.tag]
					var type : int = pb_type_from_data_type(service.field.type)
					if type == tt.type || (tt.type == PB_TYPE.LENGTHDEL && service.field.rule == PB_RULE.REPEATED && service.field.option_packed):
						var res : int = unpack_field(bytes, offset, service.field, type, service.func_ref)
						if res > 0:
							service.state = PB_SERVICE_STATE.FILLED
							offset = res
							if offset == limit:
								return offset
							elif offset > limit:
								return PB_ERR.PACKAGE_SIZE_MISMATCH
						elif res < 0:
							return res
						else:
							break
				else:
					var res : int = skip_unknown_field(bytes, offset, tt.type)
					if res > 0:
						offset = res
						if offset == limit:
							return offset
						elif offset > limit:
							return PB_ERR.PACKAGE_SIZE_MISMATCH
					elif res < 0:
						return res
					else:
						break							
			else:
				return offset
		return PB_ERR.UNDEFINED_STATE

	static func pack_message(data) -> PackedByteArray:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : PackedByteArray = PackedByteArray()
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result.append_array(pack_field(data[i].field))
			elif data[i].field.rule == PB_RULE.REQUIRED:
				print("Error: required field is not filled: Tag:", data[i].field.tag)
				return PackedByteArray()
		return result

	static func check_required(data) -> bool:
		var keys : Array = data.keys()
		for i in keys:
			if data[i].field.rule == PB_RULE.REQUIRED && data[i].state == PB_SERVICE_STATE.UNFILLED:
				return false
		return true

	static func construct_map(key_values):
		var result = {}
		for kv in key_values:
			result[kv.get_key()] = kv.get_value()
		return result
	
	static func tabulate(text : String, nesting : int) -> String:
		var tab : String = ""
		for _i in range(nesting):
			tab += DEBUG_TAB
		return tab + text
	
	static func value_to_string(value, field : PBField, nesting : int) -> String:
		var result : String = ""
		var text : String
		if field.type == PB_DATA_TYPE.MESSAGE:
			result += "{"
			nesting += 1
			text = message_to_string(value.data, nesting)
			if text != "":
				result += "\n" + text
				nesting -= 1
				result += tabulate("}", nesting)
			else:
				nesting -= 1
				result += "}"
		elif field.type == PB_DATA_TYPE.BYTES:
			result += "<"
			for i in range(value.size()):
				result += str(value[i])
				if i != (value.size() - 1):
					result += ", "
			result += ">"
		elif field.type == PB_DATA_TYPE.STRING:
			result += "\"" + value + "\""
		elif field.type == PB_DATA_TYPE.ENUM:
			result += "ENUM::" + str(value)
		else:
			result += str(value)
		return result
	
	static func field_to_string(field : PBField, nesting : int) -> String:
		var result : String = tabulate(field.name + ": ", nesting)
		if field.type == PB_DATA_TYPE.MAP:
			if field.value.size() > 0:
				result += "(\n"
				nesting += 1
				for i in range(field.value.size()):
					var local_key_value = field.value[i].data[1].field
					result += tabulate(value_to_string(local_key_value.value, local_key_value, nesting), nesting) + ": "
					local_key_value = field.value[i].data[2].field
					result += value_to_string(local_key_value.value, local_key_value, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate(")", nesting)
			else:
				result += "()"
		elif field.rule == PB_RULE.REPEATED:
			if field.value.size() > 0:
				result += "[\n"
				nesting += 1
				for i in range(field.value.size()):
					result += tabulate(str(i) + ": ", nesting)
					result += value_to_string(field.value[i], field, nesting)
					if i != (field.value.size() - 1):
						result += ","
					result += "\n"
				nesting -= 1
				result += tabulate("]", nesting)
			else:
				result += "[]"
		else:
			result += value_to_string(field.value, field, nesting)
		result += ";\n"
		return result
		
	static func message_to_string(data, nesting : int = 0) -> String:
		var DEFAULT_VALUES
		if PROTO_VERSION == 2:
			DEFAULT_VALUES = DEFAULT_VALUES_2
		elif PROTO_VERSION == 3:
			DEFAULT_VALUES = DEFAULT_VALUES_3
		var result : String = ""
		var keys : Array = data.keys()
		keys.sort()
		for i in keys:
			if data[i].field.value != null:
				if data[i].state == PB_SERVICE_STATE.UNFILLED \
				&& !data[i].field.is_map_field \
				&& typeof(data[i].field.value) == typeof(DEFAULT_VALUES[data[i].field.type]) \
				&& data[i].field.value == DEFAULT_VALUES[data[i].field.type]:
					continue
				elif data[i].field.rule == PB_RULE.REPEATED && data[i].field.value.size() == 0:
					continue
				result += field_to_string(data[i].field, nesting)
			elif data[i].field.rule == PB_RULE.REQUIRED:
				result += data[i].field.name + ": " + "error"
		return result



############### USER DATA BEGIN ################


class EntityInfo:
	extends RefCounted
	func _init():
		var service
		
		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service
		
		__player_name = PBField.new("player_name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __player_name
		data[__player_name.tag] = service
		
		__entity_type = PBField.new("entity_type", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __entity_type
		data[__entity_type.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__facing = PBField.new("facing", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __facing
		data[__facing.tag] = service
		
		__anim_state = PBField.new("anim_state", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __anim_state
		data[__anim_state.tag] = service
		
		__moving = PBField.new("moving", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __moving
		data[__moving.tag] = service
		
		__ai_state = PBField.new("ai_state", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 9, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __ai_state
		data[__ai_state.tag] = service
		
	var data = {}
	
	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> String:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_entity_id(value : String) -> void:
		__entity_id.value = value
	
	var __player_name: PBField
	func has_player_name() -> bool:
		if __player_name.value != null:
			return true
		return false
	func get_player_name() -> String:
		return __player_name.value
	func clear_player_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_player_name(value : String) -> void:
		__player_name.value = value
	
	var __entity_type: PBField
	func has_entity_type() -> bool:
		if __entity_type.value != null:
			return true
		return false
	func get_entity_type() -> int:
		return __entity_type.value
	func clear_entity_type() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__entity_type.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_entity_type(value : int) -> void:
		__entity_type.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __facing: PBField
	func has_facing() -> bool:
		if __facing.value != null:
			return true
		return false
	func get_facing() -> float:
		return __facing.value
	func clear_facing() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__facing.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_facing(value : float) -> void:
		__facing.value = value
	
	var __anim_state: PBField
	func has_anim_state() -> bool:
		if __anim_state.value != null:
			return true
		return false
	func get_anim_state() -> String:
		return __anim_state.value
	func clear_anim_state() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__anim_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_anim_state(value : String) -> void:
		__anim_state.value = value
	
	var __moving: PBField
	func has_moving() -> bool:
		if __moving.value != null:
			return true
		return false
	func get_moving() -> bool:
		return __moving.value
	func clear_moving() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__moving.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_moving(value : bool) -> void:
		__moving.value = value
	
	var __ai_state: PBField
	func has_ai_state() -> bool:
		if __ai_state.value != null:
			return true
		return false
	func get_ai_state() -> String:
		return __ai_state.value
	func clear_ai_state() -> void:
		data[9].state = PB_SERVICE_STATE.UNFILLED
		__ai_state.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_ai_state(value : String) -> void:
		__ai_state.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LoginRequest:
	extends RefCounted
	func _init():
		var service
		
		__account = PBField.new("account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __account
		data[__account.tag] = service
		
		__player_name = PBField.new("player_name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __player_name
		data[__player_name.tag] = service
		
	var data = {}
	
	var __account: PBField
	func has_account() -> bool:
		if __account.value != null:
			return true
		return false
	func get_account() -> String:
		return __account.value
	func clear_account() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_account(value : String) -> void:
		__account.value = value
	
	var __player_name: PBField
	func has_player_name() -> bool:
		if __player_name.value != null:
			return true
		return false
	func get_player_name() -> String:
		return __player_name.value
	func clear_player_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_player_name(value : String) -> void:
		__player_name.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class LoginAccepted:
	extends RefCounted
	func _init():
		var service
		
		__account = PBField.new("account", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __account
		data[__account.tag] = service
		
		__player_name = PBField.new("player_name", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __player_name
		data[__player_name.tag] = service
		
	var data = {}
	
	var __account: PBField
	func has_account() -> bool:
		if __account.value != null:
			return true
		return false
	func get_account() -> String:
		return __account.value
	func clear_account() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__account.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_account(value : String) -> void:
		__account.value = value
	
	var __player_name: PBField
	func has_player_name() -> bool:
		if __player_name.value != null:
			return true
		return false
	func get_player_name() -> String:
		return __player_name.value
	func clear_player_name() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__player_name.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_player_name(value : String) -> void:
		__player_name.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class EnterGameRequest:
	extends RefCounted
	func _init():
		var service
		
		__room_id = PBField.new("room_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __room_id
		data[__room_id.tag] = service
		
		__create_room = PBField.new("create_room", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __create_room
		data[__create_room.tag] = service
		
	var data = {}
	
	var __room_id: PBField
	func has_room_id() -> bool:
		if __room_id.value != null:
			return true
		return false
	func get_room_id() -> String:
		return __room_id.value
	func clear_room_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__room_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_room_id(value : String) -> void:
		__room_id.value = value
	
	var __create_room: PBField
	func has_create_room() -> bool:
		if __create_room.value != null:
			return true
		return false
	func get_create_room() -> bool:
		return __create_room.value
	func clear_create_room() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__create_room.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_create_room(value : bool) -> void:
		__create_room.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class WorldSnapshot:
	extends RefCounted
	func _init():
		var service
		
		__room_id = PBField.new("room_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __room_id
		data[__room_id.tag] = service
		
		var __entities_default: Array[EntityInfo] = []
		__entities = PBField.new("entities", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __entities_default)
		service = PBServiceField.new()
		service.field = __entities
		service.func_ref = Callable(self, "add_entities")
		data[__entities.tag] = service
		
		__server_tick = PBField.new("server_tick", PB_DATA_TYPE.INT64, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.INT64])
		service = PBServiceField.new()
		service.field = __server_tick
		data[__server_tick.tag] = service
		
		__self_entity_id = PBField.new("self_entity_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __self_entity_id
		data[__self_entity_id.tag] = service
		
		__map_id = PBField.new("map_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __map_id
		data[__map_id.tag] = service
		
	var data = {}
	
	var __room_id: PBField
	func has_room_id() -> bool:
		if __room_id.value != null:
			return true
		return false
	func get_room_id() -> String:
		return __room_id.value
	func clear_room_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__room_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_room_id(value : String) -> void:
		__room_id.value = value
	
	var __entities: PBField
	func get_entities() -> Array[EntityInfo]:
		return __entities.value
	func clear_entities() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__entities.value.clear()
	func add_entities() -> EntityInfo:
		var element = EntityInfo.new()
		__entities.value.append(element)
		return element
	
	var __server_tick: PBField
	func has_server_tick() -> bool:
		if __server_tick.value != null:
			return true
		return false
	func get_server_tick() -> int:
		return __server_tick.value
	func clear_server_tick() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__server_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.INT64]
	func set_server_tick(value : int) -> void:
		__server_tick.value = value
	
	var __self_entity_id: PBField
	func has_self_entity_id() -> bool:
		if __self_entity_id.value != null:
			return true
		return false
	func get_self_entity_id() -> String:
		return __self_entity_id.value
	func clear_self_entity_id() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__self_entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_self_entity_id(value : String) -> void:
		__self_entity_id.value = value
	
	var __map_id: PBField
	func has_map_id() -> bool:
		if __map_id.value != null:
			return true
		return false
	func get_map_id() -> String:
		return __map_id.value
	func clear_map_id() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__map_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_map_id(value : String) -> void:
		__map_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class MoveIntent:
	extends RefCounted
	func _init():
		var service
		
		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service
		
		__dir_x = PBField.new("dir_x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __dir_x
		data[__dir_x.tag] = service
		
		__dir_y = PBField.new("dir_y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __dir_y
		data[__dir_y.tag] = service
		
		__moving = PBField.new("moving", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __moving
		data[__moving.tag] = service
		
	var data = {}
	
	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> String:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_entity_id(value : String) -> void:
		__entity_id.value = value
	
	var __dir_x: PBField
	func has_dir_x() -> bool:
		if __dir_x.value != null:
			return true
		return false
	func get_dir_x() -> float:
		return __dir_x.value
	func clear_dir_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__dir_x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_dir_x(value : float) -> void:
		__dir_x.value = value
	
	var __dir_y: PBField
	func has_dir_y() -> bool:
		if __dir_y.value != null:
			return true
		return false
	func get_dir_y() -> float:
		return __dir_y.value
	func clear_dir_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__dir_y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_dir_y(value : float) -> void:
		__dir_y.value = value
	
	var __moving: PBField
	func has_moving() -> bool:
		if __moving.value != null:
			return true
		return false
	func get_moving() -> bool:
		return __moving.value
	func clear_moving() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__moving.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_moving(value : bool) -> void:
		__moving.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class MovementEntry:
	extends RefCounted
	func _init():
		var service
		
		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service
		
		__x = PBField.new("x", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __x
		data[__x.tag] = service
		
		__y = PBField.new("y", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __y
		data[__y.tag] = service
		
		__speed = PBField.new("speed", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __speed
		data[__speed.tag] = service
		
		__moving = PBField.new("moving", PB_DATA_TYPE.BOOL, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL])
		service = PBServiceField.new()
		service.field = __moving
		data[__moving.tag] = service
		
	var data = {}
	
	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> String:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_entity_id(value : String) -> void:
		__entity_id.value = value
	
	var __x: PBField
	func has_x() -> bool:
		if __x.value != null:
			return true
		return false
	func get_x() -> float:
		return __x.value
	func clear_x() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__x.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_x(value : float) -> void:
		__x.value = value
	
	var __y: PBField
	func has_y() -> bool:
		if __y.value != null:
			return true
		return false
	func get_y() -> float:
		return __y.value
	func clear_y() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__y.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_y(value : float) -> void:
		__y.value = value
	
	var __speed: PBField
	func has_speed() -> bool:
		if __speed.value != null:
			return true
		return false
	func get_speed() -> float:
		return __speed.value
	func clear_speed() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__speed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_speed(value : float) -> void:
		__speed.value = value
	
	var __moving: PBField
	func has_moving() -> bool:
		if __moving.value != null:
			return true
		return false
	func get_moving() -> bool:
		return __moving.value
	func clear_moving() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__moving.value = DEFAULT_VALUES_3[PB_DATA_TYPE.BOOL]
	func set_moving(value : bool) -> void:
		__moving.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class MovementFrame:
	extends RefCounted
	func _init():
		var service
		
		__server_tick = PBField.new("server_tick", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __server_tick
		data[__server_tick.tag] = service
		
		var __entries_default: Array[MovementEntry] = []
		__entries = PBField.new("entries", PB_DATA_TYPE.MESSAGE, PB_RULE.REPEATED, 2, true, __entries_default)
		service = PBServiceField.new()
		service.field = __entries
		service.func_ref = Callable(self, "add_entries")
		data[__entries.tag] = service
		
	var data = {}
	
	var __server_tick: PBField
	func has_server_tick() -> bool:
		if __server_tick.value != null:
			return true
		return false
	func get_server_tick() -> int:
		return __server_tick.value
	func clear_server_tick() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__server_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_server_tick(value : int) -> void:
		__server_tick.value = value
	
	var __entries: PBField
	func get_entries() -> Array[MovementEntry]:
		return __entries.value
	func clear_entries() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__entries.value.clear()
	func add_entries() -> MovementEntry:
		var element = MovementEntry.new()
		__entries.value.append(element)
		return element
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class EntityRemoved:
	extends RefCounted
	func _init():
		var service
		
		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service
		
	var data = {}
	
	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> String:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_entity_id(value : String) -> void:
		__entity_id.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class EntityRelocated:
	extends RefCounted
	func _init():
		var service
		
		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service
		
		__facing = PBField.new("facing", PB_DATA_TYPE.FLOAT, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT])
		service = PBServiceField.new()
		service.field = __facing
		data[__facing.tag] = service
		
	var data = {}
	
	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> String:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_entity_id(value : String) -> void:
		__entity_id.value = value
	
	var __facing: PBField
	func has_facing() -> bool:
		if __facing.value != null:
			return true
		return false
	func get_facing() -> float:
		return __facing.value
	func clear_facing() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__facing.value = DEFAULT_VALUES_3[PB_DATA_TYPE.FLOAT]
	func set_facing(value : float) -> void:
		__facing.value = value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class EntitySpawned:
	extends RefCounted
	func _init():
		var service
		
		__entity_id = PBField.new("entity_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __entity_id
		data[__entity_id.tag] = service
		
		__entity_info = PBField.new("entity_info", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __entity_info
		service.func_ref = Callable(self, "new_entity_info")
		data[__entity_info.tag] = service
		
	var data = {}
	
	var __entity_id: PBField
	func has_entity_id() -> bool:
		if __entity_id.value != null:
			return true
		return false
	func get_entity_id() -> String:
		return __entity_id.value
	func clear_entity_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__entity_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_entity_id(value : String) -> void:
		__entity_id.value = value
	
	var __entity_info: PBField
	func has_entity_info() -> bool:
		if __entity_info.value != null:
			return true
		return false
	func get_entity_info() -> EntityInfo:
		return __entity_info.value
	func clear_entity_info() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__entity_info.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_entity_info() -> EntityInfo:
		__entity_info.value = EntityInfo.new()
		return __entity_info.value
	
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ClientMessage:
	extends RefCounted
	func _init():
		var service
		
		__login_request = PBField.new("login_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __login_request
		service.func_ref = Callable(self, "new_login_request")
		data[__login_request.tag] = service
		
		__enter_game_request = PBField.new("enter_game_request", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __enter_game_request
		service.func_ref = Callable(self, "new_enter_game_request")
		data[__enter_game_request.tag] = service
		
		__move_intent = PBField.new("move_intent", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __move_intent
		service.func_ref = Callable(self, "new_move_intent")
		data[__move_intent.tag] = service
		
	var data = {}
	
	enum PayloadCase {
		PAYLOAD_NOT_SET = 0,
		LOGIN_REQUEST = 1,
		ENTER_GAME_REQUEST = 2,
		MOVE_INTENT = 3,
	}
	var _payload_case: int = 0

	var __login_request: PBField
	func has_login_request() -> bool:
		return data[1].state == PB_SERVICE_STATE.FILLED
	func get_login_request() -> LoginRequest:
		return __login_request.value
	func clear_login_request() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_login_request() -> LoginRequest:
		data[1].state = PB_SERVICE_STATE.FILLED
		_payload_case = 1
		__enter_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__move_intent.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_request.value = LoginRequest.new()
		return __login_request.value
	
	var __enter_game_request: PBField
	func has_enter_game_request() -> bool:
		return data[2].state == PB_SERVICE_STATE.FILLED
	func get_enter_game_request() -> EnterGameRequest:
		return __enter_game_request.value
	func clear_enter_game_request() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__enter_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_enter_game_request() -> EnterGameRequest:
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		data[2].state = PB_SERVICE_STATE.FILLED
		_payload_case = 2
		__move_intent.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__enter_game_request.value = EnterGameRequest.new()
		return __enter_game_request.value
	
	var __move_intent: PBField
	func has_move_intent() -> bool:
		return data[3].state == PB_SERVICE_STATE.FILLED
	func get_move_intent() -> MoveIntent:
		return __move_intent.value
	func clear_move_intent() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__move_intent.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_move_intent() -> MoveIntent:
		__login_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__enter_game_request.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[2].state = PB_SERVICE_STATE.UNFILLED
		data[3].state = PB_SERVICE_STATE.FILLED
		_payload_case = 3
		__move_intent.value = MoveIntent.new()
		return __move_intent.value
	
	func get_payload_case() -> int:
		return _payload_case
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
class ServerMessage:
	extends RefCounted
	func _init():
		var service
		
		__run_id = PBField.new("run_id", PB_DATA_TYPE.STRING, PB_RULE.OPTIONAL, 1, true, DEFAULT_VALUES_3[PB_DATA_TYPE.STRING])
		service = PBServiceField.new()
		service.field = __run_id
		data[__run_id.tag] = service
		
		__server_tick = PBField.new("server_tick", PB_DATA_TYPE.UINT64, PB_RULE.OPTIONAL, 2, true, DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64])
		service = PBServiceField.new()
		service.field = __server_tick
		data[__server_tick.tag] = service
		
		__login_accepted = PBField.new("login_accepted", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 3, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __login_accepted
		service.func_ref = Callable(self, "new_login_accepted")
		data[__login_accepted.tag] = service
		
		__world_snapshot = PBField.new("world_snapshot", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 4, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __world_snapshot
		service.func_ref = Callable(self, "new_world_snapshot")
		data[__world_snapshot.tag] = service
		
		__movement_frame = PBField.new("movement_frame", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 5, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __movement_frame
		service.func_ref = Callable(self, "new_movement_frame")
		data[__movement_frame.tag] = service
		
		__entity_spawned = PBField.new("entity_spawned", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 6, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __entity_spawned
		service.func_ref = Callable(self, "new_entity_spawned")
		data[__entity_spawned.tag] = service
		
		__entity_removed = PBField.new("entity_removed", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 7, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __entity_removed
		service.func_ref = Callable(self, "new_entity_removed")
		data[__entity_removed.tag] = service
		
		__entity_relocated = PBField.new("entity_relocated", PB_DATA_TYPE.MESSAGE, PB_RULE.OPTIONAL, 8, true, DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE])
		service = PBServiceField.new()
		service.field = __entity_relocated
		service.func_ref = Callable(self, "new_entity_relocated")
		data[__entity_relocated.tag] = service
		
	var data = {}
	
	enum PayloadCase {
		PAYLOAD_NOT_SET = 0,
		LOGIN_ACCEPTED = 3,
		WORLD_SNAPSHOT = 4,
		MOVEMENT_FRAME = 5,
		ENTITY_SPAWNED = 6,
		ENTITY_REMOVED = 7,
		ENTITY_RELOCATED = 8,
	}
	var _payload_case: int = 0

	var __run_id: PBField
	func has_run_id() -> bool:
		if __run_id.value != null:
			return true
		return false
	func get_run_id() -> String:
		return __run_id.value
	func clear_run_id() -> void:
		data[1].state = PB_SERVICE_STATE.UNFILLED
		__run_id.value = DEFAULT_VALUES_3[PB_DATA_TYPE.STRING]
	func set_run_id(value : String) -> void:
		__run_id.value = value
	
	var __server_tick: PBField
	func has_server_tick() -> bool:
		if __server_tick.value != null:
			return true
		return false
	func get_server_tick() -> int:
		return __server_tick.value
	func clear_server_tick() -> void:
		data[2].state = PB_SERVICE_STATE.UNFILLED
		__server_tick.value = DEFAULT_VALUES_3[PB_DATA_TYPE.UINT64]
	func set_server_tick(value : int) -> void:
		__server_tick.value = value
	
	var __login_accepted: PBField
	func has_login_accepted() -> bool:
		return data[3].state == PB_SERVICE_STATE.FILLED
	func get_login_accepted() -> LoginAccepted:
		return __login_accepted.value
	func clear_login_accepted() -> void:
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__login_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_login_accepted() -> LoginAccepted:
		data[3].state = PB_SERVICE_STATE.FILLED
		_payload_case = 3
		__world_snapshot.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__movement_frame.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__entity_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__entity_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__entity_relocated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__login_accepted.value = LoginAccepted.new()
		return __login_accepted.value
	
	var __world_snapshot: PBField
	func has_world_snapshot() -> bool:
		return data[4].state == PB_SERVICE_STATE.FILLED
	func get_world_snapshot() -> WorldSnapshot:
		return __world_snapshot.value
	func clear_world_snapshot() -> void:
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__world_snapshot.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_world_snapshot() -> WorldSnapshot:
		__login_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		data[4].state = PB_SERVICE_STATE.FILLED
		_payload_case = 4
		__movement_frame.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__entity_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__entity_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__entity_relocated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__world_snapshot.value = WorldSnapshot.new()
		return __world_snapshot.value
	
	var __movement_frame: PBField
	func has_movement_frame() -> bool:
		return data[5].state == PB_SERVICE_STATE.FILLED
	func get_movement_frame() -> MovementFrame:
		return __movement_frame.value
	func clear_movement_frame() -> void:
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__movement_frame.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_movement_frame() -> MovementFrame:
		__login_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__world_snapshot.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		data[5].state = PB_SERVICE_STATE.FILLED
		_payload_case = 5
		__entity_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__entity_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__entity_relocated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__movement_frame.value = MovementFrame.new()
		return __movement_frame.value
	
	var __entity_spawned: PBField
	func has_entity_spawned() -> bool:
		return data[6].state == PB_SERVICE_STATE.FILLED
	func get_entity_spawned() -> EntitySpawned:
		return __entity_spawned.value
	func clear_entity_spawned() -> void:
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__entity_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_entity_spawned() -> EntitySpawned:
		__login_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__world_snapshot.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__movement_frame.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		data[6].state = PB_SERVICE_STATE.FILLED
		_payload_case = 6
		__entity_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__entity_relocated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__entity_spawned.value = EntitySpawned.new()
		return __entity_spawned.value
	
	var __entity_removed: PBField
	func has_entity_removed() -> bool:
		return data[7].state == PB_SERVICE_STATE.FILLED
	func get_entity_removed() -> EntityRemoved:
		return __entity_removed.value
	func clear_entity_removed() -> void:
		data[7].state = PB_SERVICE_STATE.UNFILLED
		__entity_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_entity_removed() -> EntityRemoved:
		__login_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__world_snapshot.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__movement_frame.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__entity_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		data[7].state = PB_SERVICE_STATE.FILLED
		_payload_case = 7
		__entity_relocated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__entity_removed.value = EntityRemoved.new()
		return __entity_removed.value
	
	var __entity_relocated: PBField
	func has_entity_relocated() -> bool:
		return data[8].state == PB_SERVICE_STATE.FILLED
	func get_entity_relocated() -> EntityRelocated:
		return __entity_relocated.value
	func clear_entity_relocated() -> void:
		data[8].state = PB_SERVICE_STATE.UNFILLED
		__entity_relocated.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
	func new_entity_relocated() -> EntityRelocated:
		__login_accepted.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[3].state = PB_SERVICE_STATE.UNFILLED
		__world_snapshot.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[4].state = PB_SERVICE_STATE.UNFILLED
		__movement_frame.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[5].state = PB_SERVICE_STATE.UNFILLED
		__entity_spawned.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[6].state = PB_SERVICE_STATE.UNFILLED
		__entity_removed.value = DEFAULT_VALUES_3[PB_DATA_TYPE.MESSAGE]
		data[7].state = PB_SERVICE_STATE.UNFILLED
		data[8].state = PB_SERVICE_STATE.FILLED
		_payload_case = 8
		__entity_relocated.value = EntityRelocated.new()
		return __entity_relocated.value
	
	func get_payload_case() -> int:
		return _payload_case
	func _to_string() -> String:
		return PBPacker.message_to_string(data)
		
	func to_bytes() -> PackedByteArray:
		return PBPacker.pack_message(data)
		
	func from_bytes(bytes : PackedByteArray, offset : int = 0, limit : int = -1) -> int:
		var cur_limit = bytes.size()
		if limit != -1:
			cur_limit = limit
		var result = PBPacker.unpack_message(data, bytes, offset, cur_limit)
		if result == cur_limit:
			if PBPacker.check_required(data):
				if limit == -1:
					return PB_ERR.NO_ERRORS
			else:
				return PB_ERR.REQUIRED_FIELDS
		elif limit == -1 && result > 0:
			return PB_ERR.PARSE_INCOMPLETE
		return result
	
################ USER DATA END #################
