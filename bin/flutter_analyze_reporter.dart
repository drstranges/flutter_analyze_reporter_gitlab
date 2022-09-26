library flutter_analyze_reporter;

import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:crypto/crypto.dart';

void main(List<String> args) {
  if (args.contains("--help") || args.contains("-h")) {
    print("\nRun flutter analyze and parse output to create a report.\n");
    print("Usage: flutter_analyze_reporter [arguments]\n");
    print("Options:");
    print("-h, --help                  Print this usage information.");
    print("-o, --output=<file>         Output the results to a file.");
    print('                            (defaults to "report.json")');
    print(
        "-r, --reporter=<console>    The format of the output of the analysis.");
    print("                            [console (default), gitlab]\n\n");
  } else {
    final Iterable<String> argOutput = args.where(
      (element) => element.startsWith("-o") || element.startsWith("--output"),
    );
    final String output =
        argOutput.isEmpty ? "report.json" : argOutput.first.split("=")[1];

    final Iterable<String> argReporter = args.where(
      (element) => element.startsWith("-r") || element.startsWith("--reporter"),
    );
    final String reporter =
        argReporter.isEmpty ? "console" : argReporter.first.split("=")[1];
    _flutterAnalyze(output, reporter);
  }
}

void _flutterAnalyze(String output, String reporter) {
  final ProcessResult result = Process.runSync('flutter', ['analyze']);
  if (reporter == "console") {
    print(result.stdout);
    print(result.stderr);
  } else if (reporter == "gitlab") {
    String json = "[]";
    if (result.stderr.toString().isNotEmpty) {
      // TYPE • DESCRIPTION • PATH:LINE:COLUMN • CHECK_NAME
      const String delimiterSections = " • ";
      const String delimiterLocation = ":";
      json = "[";
      final List<String> lines =
          const LineSplitter().convert(result.stdout.toString());
      lines
          .where(
        (v) =>
            v.trim().isNotEmpty &&
            // type, description, location, identifier
            v.split(delimiterSections).length == 4 &&
            // path, line, column
            v.split(delimiterSections)[2].split(delimiterLocation).length == 3,
      )
          .forEach((issue) {
        final List<String> elements = issue.split(delimiterSections);
        // Map values from dart analyzer to dart code metrics for GitLab code climate widget.
        // code climate:
        // severity: info, minor, major, critical, blocker
        // category: Bug Risk, Clarity, Compatibility, Complexity, Duplication, Performance, Security, Style
        // dart analyzer:
        // severity: info, warning, error
        final String type = elements[0].trim();
        String severity;
        final List<String> categories = <String>['Clarity'];
        switch (type) {
          case "info":
            severity = "info";
            categories.add("Style");
            break;
          case "warning":
            severity = "major";
            categories.add("Security");
            break;
          case "error":
            severity = "blocker";
            categories.add("Bug Risk");
            break;
          default:
            severity = "critical";
            categories.add("Compatibility");
            break;
        }
        final String description = elements[1];
        final List<String> location = elements[2].split(delimiterLocation);
        final String path = location[0];
        final String line = location[1];
        final String column = location[2];
        final String checkName = elements[3];
        final String fingerprint = md5.convert(utf8.encode(issue)).toString();
        json +=
            """{"type":"$type","check_name":"$checkName","description":"$description","categories":${jsonEncode(categories)},"location":{"path":"$path","positions":{"begin":{"line":$line,"column":$column},"end":{"line":$line,"column":$column}}},"severity":"$severity","fingerprint":"$fingerprint"},""";
      });
      json = json.substring(0, json.length - 1); // Remove last ','
      json += "]";
    }

    final File outputCodeClimate = File(output);
    outputCodeClimate.writeAsStringSync(json);
  } else {
    print("Unknown reporter");
  }
}
