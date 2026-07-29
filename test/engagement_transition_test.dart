import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';

void main() {
  test('MK pending to confirmed increments only MK once', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.pending,
      to: EngagementStatus.confirmed,
      profession: VolunteerProfession.mk,
    );

    expect(delta, (mk: 1, pp: 0));
  });

  test('PP pending to confirmed increments only PP once', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.pending,
      to: EngagementStatus.confirmed,
      profession: VolunteerProfession.pp,
    );

    expect(delta, (mk: 0, pp: 1));
  });

  test('a second confirmation does not increment counters', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.confirmed,
      to: EngagementStatus.confirmed,
      profession: VolunteerProfession.mk,
    );

    expect(delta, (mk: 0, pp: 0));
  });

  test('MK confirmed to standby decrements only MK once', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.confirmed,
      to: EngagementStatus.standby,
      profession: VolunteerProfession.mk,
    );

    expect(delta, (mk: -1, pp: 0));
  });

  test('PP confirmed to standby decrements only PP once', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.confirmed,
      to: EngagementStatus.standby,
      profession: VolunteerProfession.pp,
    );

    expect(delta, (mk: 0, pp: -1));
  });

  test('a second standby transition does not decrement counters', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.standby,
      to: EngagementStatus.standby,
      profession: VolunteerProfession.mk,
    );

    expect(delta, (mk: 0, pp: 0));
  });

  test('MK confirmed to cancelled decrements only MK once', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.confirmed,
      to: EngagementStatus.cancelled,
      profession: VolunteerProfession.mk,
    );

    expect(delta, (mk: -1, pp: 0));
  });

  test('PP confirmed to cancelled decrements only PP once', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.confirmed,
      to: EngagementStatus.cancelled,
      profession: VolunteerProfession.pp,
    );

    expect(delta, (mk: 0, pp: -1));
  });

  test('a second cancellation does not decrement counters', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.cancelled,
      to: EngagementStatus.cancelled,
      profession: VolunteerProfession.mk,
    );

    expect(delta, (mk: 0, pp: 0));
  });

  test('MK standby to confirmed increments only MK once', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.standby,
      to: EngagementStatus.confirmed,
      profession: VolunteerProfession.mk,
    );

    expect(delta, (mk: 1, pp: 0));
  });

  test('PP standby to confirmed increments only PP once', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.standby,
      to: EngagementStatus.confirmed,
      profession: VolunteerProfession.pp,
    );

    expect(delta, (mk: 0, pp: 1));
  });

  test('a second standby confirmation does not increment counters', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.confirmed,
      to: EngagementStatus.confirmed,
      profession: VolunteerProfession.pp,
    );

    expect(delta, (mk: 0, pp: 0));
  });

  test('MK pending to standby leaves both counters unchanged', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.pending,
      to: EngagementStatus.standby,
      profession: VolunteerProfession.mk,
    );

    expect(delta, (mk: 0, pp: 0));
  });

  test('PP pending to standby leaves both counters unchanged', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.pending,
      to: EngagementStatus.standby,
      profession: VolunteerProfession.pp,
    );

    expect(delta, (mk: 0, pp: 0));
  });

  test('MK pending to cancelled leaves both counters unchanged', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.pending,
      to: EngagementStatus.cancelled,
      profession: VolunteerProfession.mk,
    );

    expect(delta, (mk: 0, pp: 0));
  });

  test('PP pending to cancelled leaves both counters unchanged', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.pending,
      to: EngagementStatus.cancelled,
      profession: VolunteerProfession.pp,
    );

    expect(delta, (mk: 0, pp: 0));
  });

  test('MK standby to cancelled leaves both counters unchanged', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.standby,
      to: EngagementStatus.cancelled,
      profession: VolunteerProfession.mk,
    );

    expect(delta, (mk: 0, pp: 0));
  });

  test('PP standby to cancelled leaves both counters unchanged', () {
    final delta = EngagementCounterTransition.delta(
      from: EngagementStatus.standby,
      to: EngagementStatus.cancelled,
      profession: VolunteerProfession.pp,
    );

    expect(delta, (mk: 0, pp: 0));
  });
}
