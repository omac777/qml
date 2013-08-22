package qml_test

import (
	"fmt"
	. "launchpad.net/gocheck"
	"launchpad.net/qml"
	"testing"
	"time"
)

func Test(t *testing.T) { TestingT(t) }

type S struct {
	engine *qml.Engine
	context *qml.Context
}

var _ = Suite(&S{})

func (s *S) SetUpSuite(c *C) {
	qml.Init(nil)
}

func (s *S) SetUpTest(c *C) {
	qml.SetLogger(c)
	s.engine = qml.NewEngine()
	s.context = s.engine.RootContext()
}

func (s *S) TearDownTest(c *C) {
	s.engine.Close()
	qml.SetLogger(nil)
}

type MyStruct struct {
	String  string
	True    bool
	False   bool
	Int     int
	Int64   int64
	Int32   int32
	Float64 float64
	Float32 float32
}

var intIs64 bool

func init() {
	var i int = 1<<31 - 1
	intIs64 = (i+1 > 0)
}

func (s *S) TestEngineClosedUse(c *C) {
	s.engine.Close()
	s.engine.Close()
	c.Assert(s.engine.RootContext, PanicMatches, "engine already closed")
}

func (s *S) TestContextSetGetString(c *C) {
	s.context.Set("key", "value")
	c.Assert(s.context.Get("key"), Equals, "value")
}

func (s *S) TestContextSetGetBool(c *C) {
	s.context.Set("bool", true)
	c.Assert(s.context.Get("bool"), Equals, true)
	s.context.Set("bool", false)
	c.Assert(s.context.Get("bool"), Equals, false)
}

func (s *S) TestContextSetGetInt64(c *C) {
	s.context.Set("key", int64(42))
	c.Assert(s.context.Get("key"), Equals, int64(42))
}

func (s *S) TestContextSetGetInt32(c *C) {
	s.context.Set("key", int32(42))
	c.Assert(s.context.Get("key"), Equals, int32(42))
}

func (s *S) TestContextSetGetInt(c *C) {
	s.context.Set("key", 42)
	if intIs64 {
		c.Assert(s.context.Get("key"), Equals, int64(42))
	} else {
		c.Assert(s.context.Get("key"), Equals, int32(42))
	}
}

func (s *S) TestContextSetGetFloat64(c *C) {
	s.context.Set("key", float64(42))
	c.Assert(s.context.Get("key"), Equals, float64(42))
}

func (s *S) TestContextSetGetFloat32(c *C) {
	s.context.Set("key", float32(42))
	c.Assert(s.context.Get("key"), Equals, float32(42))
}

func (s *S) TestContextSetGetGoValue(c *C) {
	var value MyStruct
	s.context.Set("key", &value)
	c.Assert(s.context.Get("key"), Equals, &value)
}

// TODO Test getting of non-existent.

func (s *S) TestContextSetObject(c *C) {
	s.context.SetObject(&MyStruct{
		String:  "<string value>",
		True:    true,
		False:   false,
		Int:     42,
		Int64:   42,
		Int32:   42,
		Float64: 4.2,
		Float32: 4.2,
	})

	c.Assert(s.context.Get("string"), Equals, "<string value>")
	c.Assert(s.context.Get("true"), Equals, true)
	c.Assert(s.context.Get("false"), Equals, false)
	c.Assert(s.context.Get("int64"), Equals, int64(42))
	c.Assert(s.context.Get("int32"), Equals, int32(42))
	c.Assert(s.context.Get("float64"), Equals, float64(4.2))
	c.Assert(s.context.Get("float32"), Equals, float32(4.2))

	if intIs64 {
		c.Assert(s.context.Get("int"), Equals, int64(42))
	} else {
		c.Assert(s.context.Get("int"), Equals, int32(42))
	}
}

func (s *S) TestComponentSetDataError(c *C) {
	component := qml.NewComponent(s.engine)
	err := component.SetData("file.qml", []byte("Item{}"))
	c.Assert(err, ErrorMatches, "file.qml:1 Item is not a type")
}

func (s *S) TestComponentSetData(c *C) {
	const N = 42
	s.context.Set("N", N)
	data := `
		import QtQuick 2.0
		Item { width: N*2; Component.onCompleted: console.log("N is", N) }
	`

	component := qml.NewComponent(s.engine)
	err := component.SetData("file.qml", []byte(data))
	c.Assert(err, IsNil)

	pattern := fmt.Sprintf(".* file.qml:3: N is %d\n.*", N)
	c.Assert(c.GetTestLog(), Not(Matches), pattern)

	obj := component.Create(s.context)

	c.Assert(c.GetTestLog(), Matches, pattern)
	c.Assert(obj.Get("width"), Equals, float64(N*2))
}

func (s *S) TestComponentCreateWindow(c *C) {
	data := `
		import QtQuick 2.0
		Item { width: 300; height: 200; }
	`
	component := qml.NewComponent(s.engine)
	component.SetData("file.qml", []byte(data))

	window := component.CreateWindow(s.context)
	window.Show()

	time.Sleep(600e9)
}
