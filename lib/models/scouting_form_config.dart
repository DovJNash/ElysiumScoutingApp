/// Form schemas, step titles and option lists. Edit this file when the game
/// changes - no screen code needs to be touched.
class ScoutingFormConfig {
  static const List<String> startPositions = [
    'Left trench',
    'Left bumper',
    'Hub',
    'Right bumper',
    'Right trench',
  ];

  static const List<String> exitPaths = [
    'Left trench',
    'Left bumper',
    'Right bumper',
    'Right trench',
    'None',
  ];

  static const List<String> stepTitles = [
    '1. Match Setup',
    '2. Robot Attendance',
    '3. Autonomous',
    '4. Teleop',
    '5. Defense & Climb',
  ];

  static const int minRating = 1;
  static const int maxRating = 10;

  static const List<String> speedDescriptions = [
    'Extremely slow',
    'Very slow',
    'Slow',
    'Below average',
    'Average',
    'Above average',
    'Fast',
    'Very fast',
    'Excellent',
    'Exceptional',
  ];

  static const List<String> performanceDescriptions = [
    'Very poor',
    'Poor',
    'Below average',
    'Average',
    'Good',
    'Above average',
    'Very good',
    'Excellent',
    'Outstanding',
    'Exceptional',
  ];

  static const List<String> fivePointDescriptions = [
    'Very poor',
    'Poor',
    'Average',
    'Good',
    'Excellent',
  ];

  static String fuelDescription(int count) =>
      '$count ${count == 1 ? 'fuel' : 'fuels'}';

  static String cycleDescription(int count) =>
      '$count ${count == 1 ? 'cycle' : 'cycles'} completed';
}

class SuperScoutingFieldSchema {
  final String key;
  final String label;
  final String hint;
  final int maxLines;

  const SuperScoutingFieldSchema({
    required this.key,
    required this.label,
    required this.hint,
    this.maxLines = 2,
  });
}

class SuperScoutingFormConfig {
  static const List<SuperScoutingFieldSchema> fields = [
    SuperScoutingFieldSchema(
      key: 'auto',
      label: 'Autonomous Operation & Routine',
      hint: 'Paths, game pieces scored, reliability, disruption...',
      maxLines: 3,
    ),
    SuperScoutingFieldSchema(
      key: 'autoExitPath',
      label: 'Autonomous Exit Path',
      hint: 'Left trench, left bumper, right bumper, right trench, or none',
      maxLines: 1,
    ),
    SuperScoutingFieldSchema(
      key: 'bps',
      label: 'Estimated Shooting Rate (Balls Per Second)',
      hint: 'e.g., 2.5 BPS burst / 1.8 BPS sustained',
      maxLines: 1,
    ),
    SuperScoutingFieldSchema(
      key: 'shootingLimits',
      label: 'Shooting Mechanics & Capabilities',
      hint: 'Fixed angle, turret, adjustable hood, range limits...',
    ),
    SuperScoutingFieldSchema(
      key: 'missPercent',
      label: 'Percentage of Missed Shots (%)',
      hint: 'e.g., ~15% overall, struggles from far distance',
      maxLines: 1,
    ),
    SuperScoutingFieldSchema(
      key: 'intakeSpeed',
      label: 'Fuel Passing / Alliance Zone Mechanism',
      hint: 'Over-bumper vs under-bumper, speed of pickup...',
    ),
    SuperScoutingFieldSchema(
      key: 'RobotCap',
      label: 'Robot Storage Capacity',
      hint: 'e.g., Holds up to 5 game pieces comfortably',
      maxLines: 1,
    ),
    SuperScoutingFieldSchema(
      key: 'robotLimits',
      label: 'Robot Limitations / Constraints',
      hint: 'Brownouts, tipping risk, slow recovery, fragile parts...',
    ),
    SuperScoutingFieldSchema(
      key: 'driverSkills',
      label: 'Driver Skill Assessment (Strengths & Weaknesses)',
      hint: 'Spatial awareness, evading defense, alignment precision...',
    ),
    SuperScoutingFieldSchema(
      key: 'penalties',
      label: 'Penalties & Foul Tendencies',
      hint: 'Pinning, frame perimeter, contact fouls...',
    ),
    SuperScoutingFieldSchema(
      key: 'bumpSpeed',
      label: 'Speed When Crossing the "Bump"',
      hint: 'Full speed, slows down, or avoids the bump...',
      maxLines: 1,
    ),
    SuperScoutingFieldSchema(
      key: 'DriverTechnique',
      label: 'Preferred Driving Techniques / Methods',
      hint: 'Field-centric swerve, herding, cycling lanes...',
    ),
    SuperScoutingFieldSchema(
      key: 'defenceStyle',
      label: 'Defensive Style',
      hint: 'Zone denial, lane blocking, pinning timing, or pure scorer...',
    ),
    SuperScoutingFieldSchema(
      key: 'shootingWhileMoving',
      label: 'Shooting While Moving',
      hint: 'Can the robot shoot while driving? Describe accuracy and limits.',
    ),
    SuperScoutingFieldSchema(
      key: 'climbCapability',
      label: 'Climb Capability',
      hint: 'Expected climb level, reliability, and time required.',
    ),
  ];
}
