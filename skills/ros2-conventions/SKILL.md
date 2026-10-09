---
name: ros2-conventions
description: ROS 2 and ros2_control standards and conventions from REPs, official docs, and precedent packages. Use when designing, writing, or reviewing ROS 2 packages, launch files, interfaces, controllers, or hardware components.
---

# ROS 2 Conventions

Write ROS 2 code that compiles against the target distro and looks conventional to a ROS developer. The **target distro** is the ROS distribution that the code targets.

## Source authority

When sources disagree, the higher one wins:

1. Exact target-distro API and mandatory compatibility rules.
2. REP requirements and official target-distro guidance.
3. Repository policy and CI, where the sources above leave a choice.
4. Official design rationale from `design.ros2.org`.
5. Closely related official packages.
6. Broad community convention.
7. Generic C++, Python, or CMake advice.

If two official sources conflict, check whether they target different distros. For the same distro, prefer the newer and more specific source. Say so when a conflict changes the recommendation, and say when a choice is a convention rather than a standard.

## Research before design

Before a version-sensitive or public design change:

1. Determine the target distro from branches, CI, images, manifests, or dependency versions. Do not silently assume Rolling.
2. Read the repository policy (`CONTRIBUTING.md`, `README.md`, `package.xml`, `CMakeLists.txt`, format and lint config) and two or three related packages.
3. Read the applicable REP at `reps.openrobotics.org`, then the target-distro docs at `docs.ros.org/en/<distro>/` and, for ros2_control, `control.ros.org/<distro>/`. Fall back to official repositories and maintainer issues.
4. When the question is convention, compare two related official implementations.
5. Choose the least-surprising standard solution. Build, test, lint, and load plugins.
6. Record deliberate deviations from stronger guidance.

Do not use one blog, Q&A answer, or downstream repository as the sole authority.

## Precedents

When no specification decides a style question, take a precedent from, in order: the same subsystem in the target distro, the relevant ros2_control package, a [REP-2005](https://reps.openrobotics.org/rep-2005/) package, another official package, then a maintained community package. REP-2005 is an Informational list, so its packages show convention but are not normative in every choice.

Useful families: `rclcpp` and `examples_rclcpp_*` for core C++, `common_interfaces` and `rcl_interfaces` for interface semantics, `pluginlib` and `class_loader` for plugins, `ament_cmake` and `ament_lint` for build and lint, and `ros2_control` and `ros2_controllers` for control.

Vendor and community stacks (Universal Robots, ROBOTIS, the `qiayuanl` legged stacks) answer layout and decomposition questions only, never API or style questions. `references/source-index.md` says what each one supports and how to weigh it.

## Packages

| Decision | Default | Source |
|---|---|---|
| Package name | Lowercase `a-z0-9_`, start with a letter, no consecutive `_`, at least two characters | REP-144, mandatory |
| Package semantics | A specific name. Avoid catch-all names such as `utils` and a redundant `ros` | REP-144, advised |
| Repository layout | One same-named directory per package. A single-package repository can keep the package at its root | ROS 2 docs |
| Public C++ headers | `include/<package_name>/...` | ROS 2 docs |
| Sources, tests, launch, config | `src/*.cpp`, `test/test_*.{cpp,py}`, `launch/*.launch.py`, `config/*.yaml` | Convention |
| Manifest | `package.xml` format 3 | [REP-149](https://reps.openrobotics.org/rep-0149/) |

Only the three rules marked mandatory in [REP-144](https://reps.openrobotics.org/rep-0144/) are hard requirements. Treat the rest of REP-144 as strong defaults. Create only the directories that the package needs.

| Suffix | Meaning | Source |
|---|---|---|
| `*_driver` | Driver | REP-144 |
| `*_msgs` | Messages, services, or actions | REP-144 |
| `*_<library>_plugins` | Plugins for a library | REP-144 |
| `<robot>_robot` | Robot metapackage | REP-144 |
| `<robot>_description` | URDF, xacro, and meshes | REP-144 |
| `*_bringup` | Launch-only package that starts a robot | REP-144 |
| `*_launch`, `*_tests`, `*_tutorials`, `*_demos` | Launch-, test-, tutorial-, or demo-only package | REP-144 |
| `*_ros` | ROS integration of an upstream library | REP-144 |
| `*_interfaces` | Interface package | Convention |
| `*_vendor` | Vendors an upstream dependency | Convention |
| `*_controller` | Centered on a ros2_control controller | Convention |
| `*_ros2_control` | ros2_control integration | Convention |

REP-144 suffixes are advice. Confirm a convention suffix against peer packages before you use it. `*_control` and `*_ament` have no general meaning, so do not infer one. Do not rename a stable public package only for naming aesthetics.

## Interfaces

| Decision | Default |
|---|---|
| Location | `.msg` in `msg/`, `.srv` in `srv/`, `.action` in `action/` |
| Fields | Lowercase alphanumeric with `_`, start with a letter, no trailing or consecutive `_` |
| Constants | Uppercase |
| Reusable interfaces | A dedicated interface package |
| Generated C++ headers | Snake-case names under `msg/`, `srv/`, or `action/` |

Treat public interfaces as API. Check standard interfaces and semantic REPs before you invent fields or meanings.

ROS interfaces order quaternions `x`, `y`, `z`, `w`, with the scalar last (`geometry_msgs/Quaternion`). Robotics code outside ROS is often scalar-first. Convert explicitly at the message boundary.

## C++ style

ROS 2 uses the [Google C++ Style Guide](https://google.github.io/styleguide/cppguide.html) with the deviations in [ROS 2 Code Style and Language Versions](https://docs.ros.org/en/rolling/The-ROS2-Project/Contributing/Code-Style-Language-Versions.html).

| Decision | Default |
|---|---|
| Extensions | `.hpp` and `.cpp` |
| Line length and indentation | 100 characters, two spaces, no tabs |
| Naming | `CamelCase` classes and `g_`-prefixed snake-case globals. Functions and data members follow related code. With no precedent, use `snake_case` functions and a trailing `_` on members |
| Braces | Always use braces. Cuddle `if`/`else`/`while`/`for` braces unless the condition wraps. Put function, class, enum, and struct braces on their own line |
| Comments | `///` or `/** */` for API docs, `//` for implementation |
| Pointers | `char * c` |
| Access | Prefer private members |
| Exceptions | Allowed. Never throw from a destructor |
| Boost | Avoid unless required |
| Warnings | At least `-Wall -Wextra -Wpedantic` where supported |
| Header guards | Match local style, commonly `MY_PACKAGE__MY_HEADER_HPP_` |

ROS 2 has historical naming differences. Where official style allows more than one form, match related code and do not create style-only churn.

## Python and CMake

| Decision | Default | Source |
|---|---|---|
| Python | [PEP 8](https://peps.python.org/pep-0008/) with ROS 2 changes: 100-character lines, single quotes when no escaping is needed, one import per line, hanging indents | Style guide |
| CMake | Lowercase commands with no space before `(`, `snake_case` identifiers, two-space indents with no alignment padding, no repeated conditions in `else()`/`endif()`, functions over macros | Style guide |
| Minimum CMake version | REP-2000 through Kilted, release docs for later distros | [REP-2000](https://reps.openrobotics.org/rep-2000/) |
| Dependencies | Declare every direct dependency | REP-149 |
| Lint tests | `ament_lint_auto` with `ament_lint_common` | `ament_cmake` docs |
| Linkage and include paths | Current imported targets and target-distro install guidance. Verify on older distros | `ament_cmake` docs |
| Windows libraries | Handle symbol visibility | ROS 2 docs |

For `ament_cmake` packages:

- `project()` matches the package name in `package.xml`.
- Call `ament_package()` exactly once, normally last.
- Install ROS executables to `lib/${PROJECT_NAME}`.
- Install public headers under the package-named include directory, and keep private headers out of it.

Do not copy obsolete CMake from older ROS tutorials. A clean build must not depend on undeclared packages on the developer machine.

## Public API and semantics

Treat these as API when users or other packages consume them: installed headers and symbols, interfaces, parameters, plugin names, node, topic, service, and action names, executable arguments, and public configuration keys. Keep public API small and implementation types out of public headers. Consider ABI for compiled libraries. Use deprecation paths and [SemVer](https://semver.org/) for breaking changes.

Apply semantic REPs before local conventions: [REP-103](https://reps.openrobotics.org/rep-0103/) for SI units and coordinates, [REP-105](https://reps.openrobotics.org/rep-0105/) for `base_link`, `odom`, `map`, and `earth`, and [REP-120](https://reps.openrobotics.org/rep-0120/) for humanoid frames. Search for a subsystem REP before you define units, frames, or interface semantics.

## Runtime rules

Verify the target-distro API for each area. `references/design-concepts.md` gives the rationale and marks which design articles are historical proposals.

**Real-time**

- Define the deadline, allowed jitter, and missed-deadline behavior. Low average latency is not proof.
- Keep setup and teardown off the real-time path, and with them unbounded allocation, I/O, waits, and lock contention.
- Verify that an atomic is lock-free before a guarantee depends on it. Account for priority inversion when the path takes locks.
- Measure worst-case latency, jitter, and overruns under stress.

**Time**

- Use ROS time for ROS-visible timestamps and simulation-aware algorithms, and steady time for hardware timeouts and elapsed durations. Do not mix clock domains without an explicit conversion.
- Handle pauses and forward or backward jumps in ROS time, and reset state that a jump invalidates. Uninitialized simulated time is not elapsed time.

**Launch**

- Follow the repository's Python, XML, or YAML convention. Use Python only when a declarative frontend cannot express the behavior clearly.
- Declare public arguments, pass them explicitly into included descriptions, and keep values as substitutions until launch evaluates them.
- Scope namespace, configuration, and environment changes with groups. Use package-relative substitutions, not host-specific paths.
- Sequence on events or conditions, never on sleeps.

**Command-line arguments**

- Put ROS arguments inside `--ros-args ... [--]`: `-r`/`--remap` for remaps, `-p`/`--param` for parameters, `--params-file`, and the standard logging arguments. Keep application arguments outside that scope, and do not invent ROS-like flags.
- Use node-qualified rules when one executable contains multiple nodes.

**Actions**

- Use an action for long-running work that needs feedback or cancellation, and a service for a short request-response.
- Make the concurrent-goal and preemption policy explicit. Return quickly from goal, cancel, and accepted-goal callbacks, and run the work elsewhere.
- Treat cancellation as a cooperative request. Keep the `SUCCEEDED`, `ABORTED`, and `CANCELED` meanings, and bound the feedback rate.
- Use the action API, not its underlying service and topic endpoints.

**Intra-process communication**

- Enable it deliberately for composed nodes. Interface and QoS semantics stay the same.
- `shared_ptr` is not always faster, and `unique_ptr` does not always mean zero copies. Mixed intra- and inter-process subscribers change the trade-off. Benchmark the actual graph.
- For stricter zero-copy behavior, check current loaned-message and shared-memory support.

## ros2_control

| Decision | Default |
|---|---|
| Controller | Derive from the target-distro `controller_interface` base, export a `pluginlib` plugin, and do the main work in `update()` |
| Hardware | Implement the matching Actuator, Sensor, or System interface, export a plugin, declare it in the ros2_control URDF, and do I/O in `read()` and `write()` |
| Source layout | `include/<package>/<name>.hpp` and `src/<name>.cpp` |
| Lifecycle and interfaces | Framework lifecycle callbacks, and controller-manager and resource-manager claiming |
| Long or blocking work | Asynchronous controllers |
| Parameters | `generate_parameter_library` (a strong precedent, not a standard) |
| Real-time handoff | Current `realtime_tools` patterns |

In synchronous controller-manager paths, keep `update()`, `read()`, and `write()` bounded: no sleeps, blocking I/O, or avoidable allocation. Parse messages and requests outside the real-time path, and hand over only the required data through a real-time-safe mechanism. If valid work cannot fit the loop budget, use an asynchronous controller.

Before you write a controller or hardware plugin, open the target-distro API reference. Verify the base class, every overridden signature, lifecycle return types, interface ownership, and the plugin export and CMake helpers. Compare a current example in the same distro, and read the target-distro branch of any vendor driver you consult. Do not copy a Humble skeleton into Jazzy, Kilted, or Rolling without verification.

- [API reference](https://control.ros.org/rolling/doc/api/)
- [Hardware components](https://control.ros.org/rolling/doc/ros2_control/hardware_interface/doc/hardware_components_userdoc.html)
- [Writing a hardware component](https://control.ros.org/rolling/doc/ros2_control/hardware_interface/doc/writing_new_hardware_component.html)
- [Writing a controller](https://control.ros.org/rolling/doc/ros2_controllers/doc/writing_new_controller.html)
- [Asynchronous controllers](https://control.ros.org/rolling/doc/ros2_control/controller_manager/doc/running_controllers_asynchronously.html)
- [Migration notes](https://control.ros.org/rolling/doc/ros2_control/doc/migration.html)
- [realtime_tools](https://control.ros.org/rolling/doc/realtime_tools/doc/index.html)
- [ros2_control_demos](https://github.com/ros-controls/ros2_control_demos)

**Warning:** these links point at Rolling, the development distro. Open the target-distro version of each page instead, because Rolling signatures do not always match a released distro. If swapping `/rolling/` for the distro name gives a missing page, search the target-distro docs by page title.

## Before done

- [ ] Every version-sensitive API matches the target distro.
- [ ] Package names, suffixes, and layout follow REP-144 and related packages, with no empty template directories.
- [ ] Headers, symbols, parameters, plugin names, graph names, and CLI behavior are intentional contracts, and ABI impact is considered.
- [ ] The manifest declares every direct dependency, and the package builds in a clean environment when practical.
- [ ] Tests and lint cover the change, and a test loads each new or changed plugin.
- [ ] Real-time paths stay bounded, and ros2_control code uses the framework for lifecycle and interface claiming.
- [ ] Style matches ROS policy and local code, with no unrelated churn.

## Answer design questions

Give the recommendation first. Say whether it is a requirement or a convention, and name the primary official source or precedent. Mention alternatives only when the ecosystem uses them. State weak or conflicting evidence instead of inventing a rule. Do not write a standards essay unless the user asks for the rationale.

## References

- `references/source-index.md`: official sources, precedent codebases, suffix evidence, and a maintenance procedure.
- `references/design-concepts.md`: design rationale behind the runtime rules.
- `references/examples.md`: package naming, CMake, manifest, controller, and real-time handoff examples.

Search current official sources when a decision depends on the target distro, minimum C++ or CMake versions, ros2_control signatures, deprecated APIs, new or changed REPs, or a suffix that REP-144 does not define.
