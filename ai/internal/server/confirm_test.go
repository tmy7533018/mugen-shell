package server

import (
	"testing"
	"time"
)

func TestConfirmRegistryResolveDelivers(t *testing.T) {
	r := newConfirmRegistry()
	id, ch := r.register()

	if !r.resolve(id, true) {
		t.Fatal("resolve of a registered id should report true")
	}
	select {
	case got := <-ch:
		if !got {
			t.Fatalf("channel delivered %v, want true", got)
		}
	case <-time.After(time.Second):
		t.Fatal("resolve did not deliver the answer to the channel")
	}
}

func TestConfirmRegistryUnknownID(t *testing.T) {
	r := newConfirmRegistry()
	if r.resolve("never-issued", true) {
		t.Fatal("resolve of an unknown id should report false")
	}
}

func TestConfirmRegistrySingleUse(t *testing.T) {
	r := newConfirmRegistry()
	id, _ := r.register()

	if !r.resolve(id, false) {
		t.Fatal("first resolve should report true")
	}
	if r.resolve(id, false) {
		t.Fatal("second resolve of the same id should report false")
	}
}

func TestConfirmRegistryDiscard(t *testing.T) {
	r := newConfirmRegistry()
	id, _ := r.register()

	r.discard(id)
	if r.resolve(id, true) {
		t.Fatal("resolve after discard should report false")
	}
}

func TestConfirmRegistryDistinctIDs(t *testing.T) {
	r := newConfirmRegistry()
	id1, _ := r.register()
	id2, _ := r.register()
	if id1 == id2 || id1 == "" {
		t.Fatalf("register must mint distinct non-empty ids, got %q and %q", id1, id2)
	}
}
