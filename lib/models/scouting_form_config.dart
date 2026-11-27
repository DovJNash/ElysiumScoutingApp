/// Form schemas, step titles and option lists. Edit this file when the game
/// changes - no screen code needs to be touched.
class ScoutingFormConfig {
  static const List<String> startPositions = [
    'Left trench',
    'Left bump',
    'Hub',
    'Right bump',
    'Right trench',
  ];

  static const List<String> exitPaths = [
    'Left trench',
    'Left bump',
    'Hub',
    'Right bump',
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

  static const int minRating = 0;
  static const int maxRating = 10;

  static const List<String> speedDescriptions = [
    'Over 6 seconds per fuel from first contact to secured; frequent misses or driver resets.',
    '5–6 seconds per fuel; usually needs a pause or reposition before the next pickup.',
    '4–5 seconds per fuel; pickup succeeds, but the robot often slows its route.',
    '3–4 seconds per fuel; steady pickup with occasional hesitation or a missed piece.',
    '2–3 seconds per fuel; consistent pickup while maintaining a controlled route.',
    '1.5–2 seconds per fuel; quick pickup with only brief alignment corrections.',
    '1–1.5 seconds per fuel; fast pickup with little interruption to the cycle.',
    '0.75–1 second per fuel; very rapid pickup, usually without stopping.',
    '0.5–0.75 seconds per fuel; near-continuous intake with rare hesitation.',
    'Under 0.5 seconds per fuel; fuel is secured almost immediately on contact.',
  ];

  static const List<String> performanceDescriptions = [
    'No useful teleop contribution; no reliable scoring or field task was observed.',
    'Very limited contribution; one task was attempted but repeatedly interrupted.',
    'Completes a few isolated actions; most cycles are slow, incomplete, or unreliable.',
    'Contributes intermittently; completes some cycles but has noticeable downtime.',
    'Completes the basic role at an average pace; several cycles succeed with some errors.',
    'Completes most cycles reliably; downtime and missed actions are limited.',
    'Maintains a strong pace; scoring or support actions are consistently completed.',
    'Sustains high output; transitions are efficient and failures are uncommon.',
    'Near-continuous contribution; almost every planned cycle or task is completed.',
    'Exceptional full-period impact; fast, reliable cycles with virtually no wasted time.',
  ];

  static const List<String> fivePointDescriptions = [
    'No effective result; the action rarely changes the play or is repeatedly unsuccessful.',
    'Limited effect; the action works occasionally but is often late or incomplete.',
    'Moderate result; the action usually works, with clear gaps in timing or consistency.',
    'Strong result; the action is effective and consistent, with only minor misses.',
    'Excellent result; the action is consistently effective and has a clear impact.',
  ];

  static const List<String> fuelRangeDescriptions = [
    '0–19 fuels; use this lowest band for roughly 10 or fewer.',
    '20–49 fuels (20+).',
    '50–74 fuels (50+).',
    '75–99 fuels.',
    '100–124 fuels.',
    '125–149 fuels.',
    '150–174 fuels.',
    '175–199 fuels.',
    '200–224 fuels.',
    '225–249 fuels.',
    '250 or more fuels.',
  ];

  static const List<String> accuracyDescriptions = [
    'Under 20% of attempted shots score; count only observed attempts, not passes.',
    '20–39% score; fewer than two in five observed attempts reach the target.',
    '40–59% score; roughly half of observed attempts reach the target.',
    '60–79% score; most observed attempts reach the target, with occasional misses.',
    '80–100% score; at least four in five observed attempts reach the target.',
  ];

  static const List<String> defenseDescriptions = [
    'No observable scoring delay; opponents continue their route without adjustment.',
    'Brief disruption under 10 seconds; an opponent adjusts once but quickly recovers.',
    'Moderate disruption for 10–19 seconds; at least one opponent cycle is slowed.',
    'Strong disruption for 20–29 seconds; repeated blocking or redirection is visible.',
    'Sustained disruption for 30 seconds or more; opposing scoring is repeatedly delayed.',
  ];

  static const List<String> defenseResilienceDescriptions = [
    'Cannot complete a scoring route while defended; repeatedly stopped or displaced.',
    'Completes fewer than one in four routes under defense; frequent resets are needed.',
    'Completes about half of routes under defense; often finds a workable alternate lane.',
    'Completes at least three in four routes under defense; rarely loses possession.',
    'Maintains normal scoring through defense; adapts routes with no meaningful delay.',
  ];

  static String fuelDescription(int band) =>
      fuelRangeDescriptions[band.clamp(0, maxRating).toInt()];

  static const List<int> fuelBandMidpoints = [
    10,
    35,
    62,
    87,
    112,
    137,
    162,
    187,
    212,
    237,
    275,
  ];

  static int estimatedFuelCount(int band) =>
      fuelBandMidpoints[band.clamp(0, maxRating).toInt()];

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
      hint: 'Left trench, left bump, hub, right bump, right trench, or none',
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
