# Reviewer Interface Specification

Lớp trừu tượng hóa (Abstract Adapter Pattern) giúp tách biệt hoàn toàn Logic Workflow khỏi tầng điều khiển Reviewer.

---

## 🔌 Interface Contract

Mọi Adapter dành cho Reviewer (Web Browser, API, Local LLM) đều phải thỏa mãn contract đầu ra:

```typescript
interface ReviewerAdapter {
  name: string;
  submitReviewRequest(payload: {
    prTitle: string;
    prDescription: string;
    diffContent: string;
    checklistPath: string;
  }): Promise<ReviewResultJSON>;
}
```

Dữ liệu trả về `ReviewResultJSON` **bắt buộc** phải tuân theo JSON Schema định nghĩa tại `prompts/review-schema.json`.
