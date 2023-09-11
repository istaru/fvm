import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:fvm/constants.dart';
import 'package:fvm/src/commands/global_command.dart';
import 'package:fvm/src/commands/update_command.dart';
import 'package:fvm/src/utils/logger.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:pub_updater/pub_updater.dart';

import '../exceptions.dart';
import 'commands/config_command.dart';
import 'commands/dart_command.dart';
import 'commands/destroy_command.dart';
import 'commands/doctor_command.dart';
import 'commands/exec_command.dart';
import 'commands/flavor_command.dart';
import 'commands/flutter_command.dart';
import 'commands/install_command.dart';
import 'commands/list_command.dart';
import 'commands/releases_command.dart';
import 'commands/remove_command.dart';
import 'commands/spawn_command.dart';
import 'commands/use_command.dart';
import 'version.g.dart';

/// Command Runner for FVM
class FvmCommandRunner extends CommandRunner<int> {
  /// Constructor
  FvmCommandRunner({
    PubUpdater? pubUpdater,
  })  : _pubUpdater = pubUpdater ?? PubUpdater(),
        super(
          kPackageName,
          kDescription,
        ) {
    argParser
      ..addFlag(
        'verbose',
        help: 'Print verbose output.',
      )
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print the current version.',
      );
    addCommand(InstallCommand());
    addCommand(UseCommand());
    addCommand(ListCommand());
    addCommand(RemoveCommand());
    addCommand(ReleasesCommand());
    addCommand(FlutterCommand());
    addCommand(DartCommand());
    addCommand(DoctorCommand());
    addCommand(SpawnCommand());
    addCommand(ConfigCommand());
    addCommand(FlavorCommand());
    addCommand(DestroyCommand());
    addCommand(ExecCommand());
    addCommand(UpdateCommand());
    addCommand(GlobalCommand());
  }

  final PubUpdater _pubUpdater;

  // @override
  // void printUsage() => logger.info(usage);

  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final argResults = parse(args);

      if (argResults['verbose'] == true) {
        logger.level = Level.verbose;
      }
      // Add space before output
      logger.spacer;

      final exitCode = await runCommand(argResults) ?? ExitCode.success.code;

      return exitCode;
    } on FormatException catch (e, stackTrace) {
      // On format errors, show the commands error message, root usage and
      // exit with an error code
      logger
        ..err(e.message)
        ..err('$stackTrace')
        ..info('')
        ..info(usage);
      return ExitCode.usage.code;
    } on FvmError catch (e, stackTrace) {
      logger
        ..spacer
        ..err(e.message)
        ..detail('')
        ..detail('$stackTrace');

      if (logger.level != Level.verbose) {
        logger
          ..spacer
          ..info(
            'Please run command with  --verbose if you want more information',
          );
      }

      return ExitCode.unavailable.code;
    } on ProcessException catch (e) {
      logger
        ..spacer
        ..err(e.toString())
        ..spacer;

      return e.errorCode;
    } on FvmUsageException catch (e) {
      // On usage errors, show the commands usage message and
      // exit with an error code
      logger
        ..info(e.message)
        ..spacer;

      return ExitCode.usage.code;
    } on UsageException catch (e) {
      // On usage errors, show the commands usage message and
      // exit with an error code
      logger
        ..err(e.message)
        ..info('')
        ..info(e.usage);

      return ExitCode.usage.code;
    } on Exception catch (e) {
      logger.err(e.toString());
      return ExitCode.unavailable.code;
    } finally {
      // Add spacer after the last line always
      logger.spacer;
    }
  }

  @override
  Future<int?> runCommand(ArgResults topLevelResults) async {
    // Verbose logs
    logger
      ..detail('')
      ..detail('Argument information:')
      ..detail('Top level options:');
    for (final option in topLevelResults.options) {
      if (topLevelResults.wasParsed(option)) {
        logger.detail('  - $option: ${topLevelResults[option]}');
      }
    }
    if (topLevelResults.command != null) {
      final commandResult = topLevelResults.command!;
      logger
        ..detail('  Command: ${commandResult.name}')
        ..detail('    Command options:');
      for (final option in commandResult.options) {
        if (commandResult.wasParsed(option)) {
          logger.detail('    - $option: ${commandResult[option]}');
        }
      }
    }

    final checkingForUpdate = _checkForUpdates(topLevelResults);

    // Run the command or show version
    final int? exitCode;
    if (topLevelResults['version'] == true) {
      logger.info(packageVersion);
      exitCode = ExitCode.success.code;
    } else {
      exitCode = await super.runCommand(topLevelResults);
    }

    final logOutput = await checkingForUpdate;
    logOutput?.call();

    return exitCode;
  }

  /// Checks if the current version (set by the build runner on the
  /// version.dart file) is the most recent one. If not, show a prompt to the
  /// user.
  Future<Function()?> _checkForUpdates(ArgResults args) async {
    // Command might be null
    final cmd = args.command?.name;
    final commandsToCheck = ['use', 'install', 'remove'];

    if (!commandsToCheck.contains(cmd)) return null;

    try {
      final latestVersion = await _pubUpdater.getLatestVersion(kPackageName);

      if (packageVersion == latestVersion) return null;

      return () {
        final updateAvailableLabel = lightYellow.wrap('Update available!');
        final currentVersionLabel = lightCyan.wrap(packageVersion);
        final latestVersionLabel = lightCyan.wrap(latestVersion);
        final updateCommandLabel = lightCyan.wrap('$executableName update');

        logger
          ..spacer
          ..info(
            '$updateAvailableLabel $currentVersionLabel \u2192 $latestVersionLabel',
          )
          ..info('Run $updateCommandLabel to update')
          ..spacer;
      };
    } catch (_) {
      return () {
        logger.detail("Failed to check for updates.");
      };
    }
  }
}
