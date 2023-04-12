//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//
// @dart=2.12

// ignore_for_file: unused_element, unused_import
// ignore_for_file: always_put_required_named_parameters_first
// ignore_for_file: constant_identifier_names
// ignore_for_file: lines_longer_than_80_chars

part of openapi.api;

class CreateCallTypeRequest {
  /// Returns a new [CreateCallTypeRequest] instance.
  CreateCallTypeRequest({
    this.grants = const {},
    required this.name,
    this.settings,
  });

  Map<String, List<String>> grants;

  String name;

  ///
  /// Please note: This property should have been non-nullable! Since the specification file
  /// does not include a default value (using the "default:" property), however, the generated
  /// source code must fall back to having a nullable type.
  /// Consider adding a "default:" property in the specification file to hide this note.
  ///
  CallSettingsRequest? settings;

  @override
  bool operator ==(Object other) => identical(this, other) || other is CreateCallTypeRequest &&
     other.grants == grants &&
     other.name == name &&
     other.settings == settings;

  @override
  int get hashCode =>
    // ignore: unnecessary_parenthesis
    (grants.hashCode) +
    (name.hashCode) +
    (settings == null ? 0 : settings!.hashCode);

  @override
  String toString() => 'CreateCallTypeRequest[grants=$grants, name=$name, settings=$settings]';

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
      json[r'grants'] = this.grants;
      json[r'name'] = this.name;
    if (this.settings != null) {
      json[r'settings'] = this.settings;
    } else {
      json[r'settings'] = null;
    }
    return json;
  }

  /// Returns a new [CreateCallTypeRequest] instance and imports its values from
  /// [value] if it's a [Map], null otherwise.
  // ignore: prefer_constructors_over_static_methods
  static CreateCallTypeRequest? fromJson(dynamic value) {
    if (value is Map) {
      final json = value.cast<String, dynamic>();

      // Ensure that the map contains the required keys.
      // Note 1: the values aren't checked for validity beyond being non-null.
      // Note 2: this code is stripped in release mode!
      assert(() {
        requiredKeys.forEach((key) {
          assert(json.containsKey(key), 'Required key "CreateCallTypeRequest[$key]" is missing from JSON.');
          assert(json[key] != null, 'Required key "CreateCallTypeRequest[$key]" has a null value in JSON.');
        });
        return true;
      }());

      return CreateCallTypeRequest(
        grants: json[r'grants'] == null
          ? const {}
            : mapCastOfType<String, List<String>>(json, r'grants') ?? const {},
        name: mapValueOfType<String>(json, r'name')!,
        settings: CallSettingsRequest.fromJson(json[r'settings']),
      );
    }
    return null;
  }

  static List<CreateCallTypeRequest>? listFromJson(dynamic json, {bool growable = false,}) {
    final result = <CreateCallTypeRequest>[];
    if (json is List && json.isNotEmpty) {
      for (final row in json) {
        final value = CreateCallTypeRequest.fromJson(row);
        if (value != null) {
          result.add(value);
        }
      }
    }
    return result.toList(growable: growable);
  }

  static Map<String, CreateCallTypeRequest> mapFromJson(dynamic json) {
    final map = <String, CreateCallTypeRequest>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateCallTypeRequest.fromJson(entry.value);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  // maps a json object with a list of CreateCallTypeRequest-objects as value to a dart map
  static Map<String, List<CreateCallTypeRequest>> mapListFromJson(dynamic json, {bool growable = false,}) {
    final map = <String, List<CreateCallTypeRequest>>{};
    if (json is Map && json.isNotEmpty) {
      json = json.cast<String, dynamic>(); // ignore: parameter_assignments
      for (final entry in json.entries) {
        final value = CreateCallTypeRequest.listFromJson(entry.value, growable: growable,);
        if (value != null) {
          map[entry.key] = value;
        }
      }
    }
    return map;
  }

  /// The list of required keys that must be present in a JSON.
  static const requiredKeys = <String>{
    'name',
  };
}
