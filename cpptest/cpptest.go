// Package cpptest is an internal test helper.
package cpptest

// #cgo CXXFLAGS: -std=c++0x -Wall -fno-strict-aliasing -I..
// #cgo LDFLAGS: -lstdc++
//
// #cgo pkg-config: Qt5Core
//
// #include "cpptest.h"
//
import "C"

import (
	"gopkg.in/v0/qml"
)

func NewTestType(engine *qml.Engine) qml.Object {
	var obj qml.Object 
	qml.RunMain(func() {
		addr := C.newTestType()
		obj = qml.CommonOf(addr, engine)
	})
	return obj
}
