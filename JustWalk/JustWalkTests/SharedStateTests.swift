//
//  SharedStateTests.swift
//  JustWalkTests
//
//  Parent suite that serializes all test suites sharing singleton state.
//  Each test struct is nested inside this enum via extensions in their own files.
//

import Testing

@Suite(.serialized)
enum SharedStateTests {}
