import Foundation

/// Static, bundled catalog of rehabilitation exercises — no network fetch,
/// no downloaded images/video, no third-party dataset. Content is original
/// copy informed by widely-published, non-proprietary rehabilitation
/// principles (isometric/eccentric tendon loading, controlled joint
/// mobility, post-injury muscle activation); see each exercise's
/// `referenceNote` for the specific principle it draws on. Mirrors the
/// "pure Swift catalog, no JSON" pattern already used by `SeedData.exercises`.
enum RehabSeedData {
    static let disclaimer = RehabLocalizedText(key: "rehab_this_section_is_educational_and_does_not_replace_an_in_person_evaluation")

    static let exercises: [RehabExercise] = [
        // MARK: - Shoulder

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: RehabLocalizedText(key: "rehab_isometric_external_rotation_hold"),
            bodyRegion: .shoulder,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .subacute,
            sets: 5,
            reps: nil,
            holdSeconds: 45,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(key: "rehab_anchor_a_light_resistance_band_at_elbow_height_and_stand_side_on_to_it"),
                RehabLocalizedText(key: "rehab_tuck_your_elbow_against_your_side_bent_to_90_holding_the_band_across_you"),
                RehabLocalizedText(key: "rehab_without_letting_the_elbow_drift_from_your_side_rotate_your_forearm_outwa"),
                RehabLocalizedText(key: "rehab_hold_at_a_comfortable_end_range_for_the_target_time_then_release_slowly")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_mild_to_moderate_discomfort_up_to_about_4_10_during_the_hold_is_commonly"),
            cautions: [
                RehabLocalizedText(key: "rehab_avoid_overhead_positions_while_shoulder_pain_is_acute"),
                RehabLocalizedText(key: "rehab_stop_if_you_feel_numbness_tingling_or_sharp_pain_down_the_arm")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_based_on_isometric_loading_for_pain_modulation_used_in_early_stage_rotat")
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: RehabLocalizedText(key: "rehab_pendulum_swings"),
            bodyRegion: .shoulder,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 3,
            reps: 10,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(key: "rehab_lean_forward_slightly_supporting_yourself_on_a_table_or_chair_with_your"),
                RehabLocalizedText(key: "rehab_let_the_affected_arm_hang_relaxed_toward_the_floor"),
                RehabLocalizedText(key: "rehab_gently_sway_your_body_to_swing_the_arm_in_small_circles_letting_gravity"),
                RehabLocalizedText(key: "rehab_reverse_direction_halfway_through_the_set")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_this_should_feel_like_gentle_motion_not_stretching_into_pain_keep_it_und"),
            cautions: [
                RehabLocalizedText(key: "rehab_do_not_actively_swing_the_arm_with_muscle_effort_motion_should_come_from")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_passive_pendular_mobility_is_a_long_standing_staple_of_early_post_immobi")
        ),

        // MARK: - Elbow

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            name: RehabLocalizedText(key: "rehab_isometric_wrist_extension_hold"),
            bodyRegion: .elbow,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .subacute,
            sets: 5,
            reps: nil,
            holdSeconds: 45,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(key: "rehab_rest_your_forearm_on_a_table_palm_facing_down_wrist_just_past_the_edge"),
                RehabLocalizedText(key: "rehab_with_your_other_hand_press_down_gently_on_the_back_of_your_hand"),
                RehabLocalizedText(key: "rehab_resist_by_trying_to_lift_your_hand_upward_without_actually_moving_it"),
                RehabLocalizedText(key: "rehab_hold_steady_tension_for_the_target_time_then_rest_fully_before_the_next")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_working_discomfort_up_to_about_4_10_during_the_hold_is_generally_accepta"),
            cautions: [
                RehabLocalizedText(key: "rehab_avoid_gripping_activities_that_reproduce_sharp_elbow_pain_until_this_fee")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_based_on_isometric_analgesic_loading_protocols_studied_for_lateral_elbow")
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
            name: RehabLocalizedText(key: "rehab_isometric_wrist_flexion_hold"),
            bodyRegion: .elbow,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .subacute,
            sets: 5,
            reps: nil,
            holdSeconds: 45,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(key: "rehab_rest_your_forearm_on_a_table_palm_facing_up_wrist_just_past_the_edge"),
                RehabLocalizedText(key: "rehab_with_your_other_hand_press_down_gently_on_your_palm"),
                RehabLocalizedText(key: "rehab_resist_by_trying_to_curl_your_hand_upward_without_actually_moving_it"),
                RehabLocalizedText(key: "rehab_hold_steady_tension_for_the_target_time")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_same_guidance_as_other_tendon_holds_up_to_4_10_discomfort_is_generally_f"),
            cautions: [
                RehabLocalizedText(key: "rehab_avoid_heavy_gripping_or_lifting_with_a_bent_wrist_until_symptoms_improve")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_mirrors_the_isometric_loading_approach_used_for_medial_elbow_tendinopath")
        ),

        // MARK: - Wrist

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
            name: RehabLocalizedText(key: "rehab_wrist_circles_tendon_glides"),
            bodyRegion: .wrist,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 2,
            reps: 10,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(key: "rehab_extend_your_arm_and_make_a_loose_fist"),
                RehabLocalizedText(key: "rehab_slowly_circle_the_wrist_10_times_in_each_direction"),
                RehabLocalizedText(key: "rehab_then_open_the_hand_fully_straighten_fingers_and_slide_through_a_hook_ful"),
                RehabLocalizedText(key: "rehab_move_slowly_and_stay_within_a_pain_free_range")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_this_is_mobility_work_not_a_strength_challenge_keep_it_under_3_10_and_ne"),
            cautions: [
                RehabLocalizedText(key: "rehab_stop_if_you_feel_catching_locking_or_sharp_pain_in_a_specific_finger_or")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_tendon_gliding_sequences_are_a_standard_early_mobility_technique_in_hand")
        ),

        // MARK: - Knee

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
            name: RehabLocalizedText(key: "rehab_isometric_spanish_squat_hold"),
            bodyRegion: .knee,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .subacute,
            sets: 5,
            reps: nil,
            holdSeconds: 45,
            restSeconds: 90,
            instructions: [
                RehabLocalizedText(key: "rehab_loop_a_strong_band_around_a_sturdy_anchor_at_knee_height_and_around_the"),
                RehabLocalizedText(key: "rehab_stand_facing_away_from_the_anchor_with_feet_hip_width_apart_leaning_back"),
                RehabLocalizedText(key: "rehab_bend_your_knees_to_a_comfortable_mid_range_squat_keeping_your_torso_upri"),
                RehabLocalizedText(key: "rehab_hold_the_position_keeping_tension_through_the_front_of_the_knee_then_sta")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_up_to_4_10_pain_during_the_hold_is_commonly_considered_acceptable_for_pa"),
            cautions: [
                RehabLocalizedText(key: "rehab_avoid_jumping_or_deep_squatting_sports_until_this_feels_comfortable")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_based_on_the_isometric_protocol_studied_for_in_season_patellar_tendinopa")
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000007")!,
            name: RehabLocalizedText(key: "rehab_heel_slides"),
            bodyRegion: .knee,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 3,
            reps: 12,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(key: "rehab_lie_on_your_back_with_legs_straight"),
                RehabLocalizedText(key: "rehab_slowly_slide_your_heel_toward_your_glutes_bending_the_knee_as_far_as_com"),
                RehabLocalizedText(key: "rehab_hold_briefly_at_end_range_then_slide_back_to_straight")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_a_mild_pulling_or_stretching_sensation_is_expected_keep_sharp_pain_out_o"),
            cautions: [
                RehabLocalizedText(key: "rehab_do_not_force_the_bend_past_a_point_of_resistance_regain_range_gradually")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_standard_early_phase_knee_mobility_drill_after_injury_or_surgery_to_rest")
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000008")!,
            name: RehabLocalizedText(key: "rehab_quad_set"),
            bodyRegion: .knee,
            structureFocus: .muscle,
            protocolType: .activation,
            stage: .acute,
            sets: 3,
            reps: 10,
            holdSeconds: 5,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(key: "rehab_sit_or_lie_with_the_leg_straight_a_small_rolled_towel_under_the_knee"),
                RehabLocalizedText(key: "rehab_press_the_back_of_the_knee_down_into_the_towel_tightening_the_muscle_on"),
                RehabLocalizedText(key: "rehab_hold_then_relax_fully_between_reps")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_this_should_feel_like_effort_not_pain_keep_discomfort_under_3_10"),
            cautions: [
                RehabLocalizedText(key: "rehab_stop_if_the_knee_swells_or_feels_warmer_than_usual_after_sessions")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_a_standard_early_quadriceps_activation_drill_used_broadly_in_post_injury")
        ),

        // MARK: - Ankle / Achilles

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000009")!,
            name: RehabLocalizedText(key: "rehab_eccentric_heel_drop"),
            bodyRegion: .ankle,
            structureFocus: .tendon,
            protocolType: .eccentric,
            stage: .returnToActivity,
            sets: 3,
            reps: 15,
            holdSeconds: nil,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(key: "rehab_stand_on_the_edge_of_a_step_with_your_heels_off_the_back_using_a_rail_fo"),
                RehabLocalizedText(key: "rehab_rise_onto_the_toes_of_both_feet"),
                RehabLocalizedText(key: "rehab_shift_your_weight_onto_the_affected_leg_and_slowly_lower_the_heel_below"),
                RehabLocalizedText(key: "rehab_use_the_other_leg_to_help_rise_back_up_then_repeat_do_one_set_with_the_k")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_pain_up_to_4_10_during_the_lowering_phase_is_generally_considered_accept"),
            cautions: [
                RehabLocalizedText(key: "rehab_do_not_perform_after_a_suspected_achilles_rupture_or_acute_tear_get_that"),
                RehabLocalizedText(key: "rehab_progress_the_daily_volume_gradually_this_protocol_is_traditionally_built")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_based_on_alfredson_s_heavy_load_eccentric_calf_raise_protocol_for_achill")
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000a")!,
            name: RehabLocalizedText(key: "rehab_isometric_calf_raise_hold"),
            bodyRegion: .ankle,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .acute,
            sets: 5,
            reps: nil,
            holdSeconds: 30,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(key: "rehab_stand_holding_onto_a_support_feet_flat"),
                RehabLocalizedText(key: "rehab_rise_onto_the_balls_of_both_feet_to_a_comfortable_mid_range_height"),
                RehabLocalizedText(key: "rehab_hold_steady_keeping_tension_through_the_calf_and_achilles"),
                RehabLocalizedText(key: "rehab_lower_under_control_and_rest_fully_before_the_next_hold")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_a_gentler_starting_point_than_the_eccentric_drop_keep_discomfort_around"),
            cautions: [
                RehabLocalizedText(key: "rehab_use_this_version_when_the_tendon_is_too_irritable_for_the_full_eccentric")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_isometric_loading_is_used_as_a_lower_irritability_entry_point_before_pro")
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000b")!,
            name: RehabLocalizedText(key: "rehab_ankle_alphabet"),
            bodyRegion: .ankle,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 2,
            reps: 1,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(key: "rehab_sit_with_the_leg_extended_and_the_ankle_relaxed_off_a_support"),
                RehabLocalizedText(key: "rehab_using_only_your_foot_draw_each_letter_of_the_alphabet_in_the_air"),
                RehabLocalizedText(key: "rehab_move_slowly_and_stay_within_a_comfortable_range")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_mild_stiffness_is_normal_after_a_sprain_keep_this_under_3_10_and_avoid_f"),
            cautions: [
                RehabLocalizedText(key: "rehab_avoid_weight_bearing_versions_until_cleared_if_there_was_a_recent_fractu")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_a_widely_used_low_load_multi_directional_mobility_drill_for_early_ankle")
        ),

        // MARK: - Hip

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000c")!,
            name: RehabLocalizedText(key: "rehab_isometric_bridge_hold"),
            bodyRegion: .hip,
            structureFocus: .tendon,
            protocolType: .isometricHold,
            stage: .subacute,
            sets: 4,
            reps: nil,
            holdSeconds: 30,
            restSeconds: 60,
            instructions: [
                RehabLocalizedText(key: "rehab_lie_on_your_back_with_knees_bent_feet_flat_on_the_floor"),
                RehabLocalizedText(key: "rehab_squeeze_your_glutes_and_lift_your_hips_to_a_comfortable_mid_range_height"),
                RehabLocalizedText(key: "rehab_hold_steady_avoiding_any_pinching_at_the_front_of_the_hip"),
                RehabLocalizedText(key: "rehab_lower_slowly_and_rest_before_the_next_hold")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_up_to_4_10_in_the_buttock_tendon_area_is_generally_acceptable_front_of_h"),
            cautions: [
                RehabLocalizedText(key: "rehab_reduce_the_height_of_the_bridge_if_you_feel_hip_pinching_rather_than_mus")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_applies_isometric_tendon_loading_principles_as_used_for_patellar_achille")
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000d")!,
            name: RehabLocalizedText(key: "rehab_90_90_hip_switch"),
            bodyRegion: .hip,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .subacute,
            sets: 3,
            reps: 8,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(key: "rehab_sit_on_the_floor_with_both_knees_bent_to_90_one_leg_in_front_and_one_out"),
                RehabLocalizedText(key: "rehab_keeping_your_seat_on_the_floor_slowly_rotate_both_legs_to_the_other_side"),
                RehabLocalizedText(key: "rehab_move_slowly_and_use_your_hands_on_the_floor_for_support_as_needed")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_expect_a_stretching_sensation_in_the_hip_not_joint_pain_keep_it_under_3"),
            cautions: [
                RehabLocalizedText(key: "rehab_reduce_the_range_if_you_feel_pinching_at_the_front_of_the_hip")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_a_standard_controlled_hip_rotation_mobility_drill_used_in_hip_and_lower")
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000e")!,
            name: RehabLocalizedText(key: "rehab_side_lying_clamshell"),
            bodyRegion: .hip,
            structureFocus: .muscle,
            protocolType: .activation,
            stage: .subacute,
            sets: 3,
            reps: 15,
            holdSeconds: nil,
            restSeconds: 45,
            instructions: [
                RehabLocalizedText(key: "rehab_lie_on_your_side_with_hips_and_knees_bent_feet_together_in_line_with_you"),
                RehabLocalizedText(key: "rehab_keeping_your_feet_together_lift_the_top_knee_like_opening_a_clamshell"),
                RehabLocalizedText(key: "rehab_avoid_rolling_your_hips_backward_keep_the_movement_isolated_to_the_hip"),
                RehabLocalizedText(key: "rehab_lower_under_control_and_repeat")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_this_should_feel_like_muscular_effort_in_the_side_of_the_hip_not_joint_p"),
            cautions: [
                RehabLocalizedText(key: "rehab_stop_rolling_the_hips_backward_if_you_notice_it_creeping_in_that_usually")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_a_standard_gluteus_medius_activation_exercise_used_broadly_in_hip_knee_a")
        ),

        // MARK: - Lower back

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-00000000000f")!,
            name: RehabLocalizedText(key: "rehab_cat_camel_mobility"),
            bodyRegion: .lowerBack,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 2,
            reps: 10,
            holdSeconds: nil,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(key: "rehab_start_on_hands_and_knees_spine_neutral"),
                RehabLocalizedText(key: "rehab_slowly_round_your_back_toward_the_ceiling_tucking_chin_and_pelvis"),
                RehabLocalizedText(key: "rehab_then_slowly_arch_the_other_way_lifting_chest_and_tailbone"),
                RehabLocalizedText(key: "rehab_move_through_a_comfortable_range_at_a_slow_controlled_pace")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_this_should_feel_like_easy_motion_keep_any_discomfort_under_3_10_and_avo"),
            cautions: [
                RehabLocalizedText(key: "rehab_stop_if_pain_radiates_down_a_leg_or_arm_that_needs_a_professional_assess")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_a_classic_gentle_spinal_mobility_drill_used_across_low_back_rehabilitati")
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000010")!,
            name: RehabLocalizedText(key: "rehab_bird_dog"),
            bodyRegion: .lowerBack,
            structureFocus: .muscle,
            protocolType: .activation,
            stage: .subacute,
            sets: 3,
            reps: 8,
            holdSeconds: 5,
            restSeconds: 45,
            instructions: [
                RehabLocalizedText(key: "rehab_start_on_hands_and_knees_spine_neutral_core_gently_braced"),
                RehabLocalizedText(key: "rehab_slowly_extend_one_arm_forward_and_the_opposite_leg_back_keeping_your_hip"),
                RehabLocalizedText(key: "rehab_hold_briefly_then_return_with_control_and_switch_sides"),
                RehabLocalizedText(key: "rehab_avoid_rotating_or_dropping_the_hips_throughout_the_movement")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_expect_low_back_and_core_effort_not_sharp_pain_keep_discomfort_under_3_1"),
            cautions: [
                RehabLocalizedText(key: "rehab_if_you_can_t_keep_your_hips_level_reduce_the_range_e_g_arm_only_or_leg_o")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_a_core_stability_exercise_widely_used_in_evidence_based_low_back_rehabil")
        ),

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000011")!,
            name: RehabLocalizedText(key: "rehab_dead_bug"),
            bodyRegion: .lowerBack,
            structureFocus: .muscle,
            protocolType: .activation,
            stage: .subacute,
            sets: 3,
            reps: 10,
            holdSeconds: nil,
            restSeconds: 45,
            instructions: [
                RehabLocalizedText(key: "rehab_lie_on_your_back_arms_reaching_toward_the_ceiling_hips_and_knees_bent_to"),
                RehabLocalizedText(key: "rehab_gently_brace_your_core_so_your_lower_back_stays_in_contact_with_the_floo"),
                RehabLocalizedText(key: "rehab_slowly_lower_one_arm_overhead_and_the_opposite_leg_toward_the_floor"),
                RehabLocalizedText(key: "rehab_return_to_start_with_control_and_switch_sides_keeping_the_back_flat_thro")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_this_should_feel_like_controlled_core_effort_if_your_lower_back_arches_o"),
            cautions: [
                RehabLocalizedText(key: "rehab_keep_the_range_small_enough_that_the_lower_back_never_lifts_off_the_floo")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_a_standard_anti_extension_core_stability_drill_used_in_low_back_rehabili")
        ),

        // MARK: - Neck

        RehabExercise(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000012")!,
            name: RehabLocalizedText(key: "rehab_chin_tuck"),
            bodyRegion: .neck,
            structureFocus: .joint,
            protocolType: .mobility,
            stage: .acute,
            sets: 3,
            reps: 10,
            holdSeconds: 5,
            restSeconds: 30,
            instructions: [
                RehabLocalizedText(key: "rehab_sit_or_stand_tall_looking_straight_ahead"),
                RehabLocalizedText(key: "rehab_gently_draw_your_chin_straight_back_as_if_making_a_double_chin_without_t"),
                RehabLocalizedText(key: "rehab_hold_briefly_feeling_a_gentle_stretch_at_the_base_of_the_skull"),
                RehabLocalizedText(key: "rehab_release_slowly_back_to_neutral")
            ],
            painGuidance: RehabLocalizedText(key: "rehab_expect_a_mild_stretch_not_pain_keep_it_under_3_10_and_stop_if_you_feel_d"),
            cautions: [
                RehabLocalizedText(key: "rehab_stop_if_you_feel_dizziness_tingling_in_the_arms_or_a_sharp_increase_in_h")
            ],
            referenceNote: RehabLocalizedText(key: "rehab_a_standard_deep_neck_flexor_activation_and_postural_mobility_drill_used")
        )
    ]
}
