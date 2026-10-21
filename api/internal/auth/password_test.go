package auth

import "testing"

// 密碼以 argon2id 雜湊存放（前綴 $argon2id$）。正確密碼可驗證，錯誤密碼必須失敗。
func TestHashVerifyArgon2id(t *testing.T) {
	h, err := Hash("password123")
	if err != nil {
		t.Fatal(err)
	}
	if h[:10] != "$argon2id$" {
		t.Fatalf("want argon2id prefix, got %q", h[:min(20, len(h))])
	}
	if !Verify("password123", h) {
		t.Fatal("verify should succeed")
	}
	if Verify("wrong-password", h) {
		t.Fatal("verify should fail for wrong password")
	}
}
