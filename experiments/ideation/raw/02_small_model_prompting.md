# Prompt Engineering for Smaller LLMs (7B-13B Parameters)

Research compilation on techniques to optimize prompts for models with limited capacity.

---

## Executive Summary

Smaller LLMs (under 30B parameters) require fundamentally different prompting strategies than their larger counterparts. The key insight is that **smaller models need more scaffolding, clearer structure, and explicit guidance** to compensate for their reduced reasoning capacity. This document synthesizes research and practical techniques across seven key areas.

---

## 1. Prompt Compression Techniques

### The Problem
Smaller models have limited context windows (e.g., Gemma models: 8K tokens vs. Gemini 1.5 Pro: 1M tokens). Every token matters more.

### LLMLingua Approach
Microsoft's LLMLingua uses a small language model (GPT2-small or LLaMA-7B) to identify and remove unimportant tokens from prompts, achieving **up to 20x compression** while preserving capabilities.

Key results:
- GPT-2-small achieved 76.27 performance score under 1/4-shot constraint
- 20-30% latency reduction in generation
- Compressed prompts remain effective for LLMs even if hard for humans to read

### Practical Compression Strategies

```
BEFORE (verbose):
"I would like you to please help me by summarizing the following
article that I have provided below. The article is about climate
change and its effects on coastal cities."

AFTER (compressed):
"Summarize this climate change article about coastal cities:"
```

**Techniques:**
1. Remove stop words ("a", "the", "is") when not semantically critical
2. Eliminate redundant phrasing ("please help me by")
3. Use shorter synonyms ("use" vs "utilize")
4. Front-load critical information

### Token Budget Strategy
```
Context: 40% of available tokens
Instructions: 20% of available tokens
Examples: 30% of available tokens
Output space: 10% of available tokens
```

---

## 2. Few-Shot Learning Optimizations

### Key Finding: Example Difficulty Matters
Research shows smaller models prefer simpler examples:
- **LLaMA2-7B**: Prefers Chain-of-Thought examples at difficulty level 3-4
- **LLaMA2-13B**: Prefers examples at difficulty level 4+

### Example Selection Strategies

**For Small Models (7B):**
```
# Use simple, clear examples that demonstrate the exact pattern
Example 1: Input: "apple" -> Output: "fruit"
Example 2: Input: "carrot" -> Output: "vegetable"
Example 3: Input: "salmon" -> Output: "fish"

Now classify: "banana" ->
```

**For Medium Models (13B):**
```
# Can handle slightly more nuanced examples
Example 1: Input: "The sunset painted the sky orange" -> Sentiment: positive
Example 2: Input: "Traffic made me late again" -> Sentiment: negative

Classify: "My coffee was lukewarm but the pastry was excellent" ->
```

### Optimal Number of Examples
- **Sweet spot**: 3-5 examples for most tasks
- Going from 0 to 5 examples provides most gains
- Diminishing returns after ~10 examples
- More examples = less room for actual task input

### CoT-Influx: Maximizing Limited Context
Research addresses limited context windows by:
1. Selecting the most useful examples automatically
2. Pruning redundant tokens within examples
3. Using a coarse-to-fine pruner as a plug-and-play module

---

## 3. Chain-of-Thought Adaptations for Smaller Models

### Critical Warning
Standard CoT **does not help** models under ~100B parameters. Smaller models produce "fluent but illogical" reasoning chains that hurt performance.

### What Works Instead

#### Least-to-Most Prompting
Break problems into progressively harder sub-problems:

```
Task: "What is the last letter of 'apple banana cherry'?"

Step 1: "What is the last letter of 'apple'?" -> "e"
Step 2: "Using that 'apple' ends in 'e', what is the last letter of 'apple banana'?" -> "a"
Step 3: "Using that, what is the last letter of 'apple banana cherry'?" -> "y"
```

Results: **74% accuracy** (vs. 34% with standard CoT on 12-word problems)

#### Chain of Draft (CoD)
Instead of verbose reasoning, generate concise intermediate "drafts":

```
STANDARD COT (too verbose for small models):
"First, I need to consider that apples are fruits, and fruits grow on trees.
Trees are plants that photosynthesize. Given this botanical context..."

CHAIN OF DRAFT:
"apple = fruit | grows on trees | answer: plant-based food"
```

#### Decomposed Prompting (DecomP)
Use specialized sub-task handlers:

```python
# Instead of one complex prompt:
"Parse this SQL, validate it, and explain any errors"

# Decompose into:
prompt_1 = "Extract the table names from this SQL"  # -> ["users", "orders"]
prompt_2 = "Check if these tables exist: {tables}"   # -> validation result
prompt_3 = "Given {validation}, explain the issue"   # -> human explanation
```

**Results**: DecomP outperforms both standard prompting and CoT on GPT-3 for complex tasks.

### Simple Step-by-Step Alternative
For small models, a simple directive often outperforms complex CoT:

```
"Solve this step by step, showing only essential calculations:
What is 15% of 80?"

Step 1: 15% = 0.15
Step 2: 0.15 x 80 = 12
Answer: 12
```

---

## 4. Structured Output Techniques

### The Challenge
Small open-weight models (like Llama3.2 3B) "perform poorly for all but the simplest schema." Average success rate across models: **82.55%** with high variance (0-100%).

### Grammar-Constrained Decoding
Force valid output structure at the token level:

```python
# Using Outlines library
from outlines import models, generate

model = models.transformers("mistralai/Mistral-7B-v0.1")

# Define valid JSON schema
schema = {
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer"}
    }
}

generator = generate.json(model, schema)
result = generator("Extract person info: John is 25 years old")
# Guaranteed valid JSON: {"name": "John", "age": 25}
```

**Key insight**: Grammar constraints can substitute for in-context examples, especially beneficial for resource-constrained applications.

### SLOT (Structured LLM Output Transformer)
Use a fine-tuned lightweight model as a post-processing layer:
- Even **Llama-3.2-1B** can match larger models' structured output when equipped with SLOT
- Model-agnostic approach works across various LLMs

### Practical JSON Techniques

**Explicit Schema in Prompt:**
```
Output your response as JSON matching this exact schema:
{
  "answer": string (the main answer),
  "confidence": number (0.0 to 1.0),
  "reasoning": string (brief explanation)
}

Do not include any text outside the JSON object.
```

**Defensive Parsing:**
```ruby
def safe_parse(response)
  # Try to extract JSON from potentially malformed output
  json_match = response.match(/\{[\s\S]*\}/)
  return nil unless json_match

  begin
    JSON.parse(json_match[0])
  rescue JSON::ParserError
    # Use json_repair or similar library
    JsonRepair.repair_and_parse(json_match[0])
  end
end
```

### XML Tags for Structure (Claude-optimized but broadly useful)

```xml
<task>Classify the sentiment</task>
<input>The product arrived damaged but customer service was helpful</input>
<format>
  <sentiment>positive|negative|mixed</sentiment>
  <confidence>high|medium|low</confidence>
</format>
```

Benefits:
- Clear separation of prompt components
- Reduces instruction/content confusion
- Easier to parse outputs
- Works well with models trained on XML-heavy data

---

## 5. Making Prompts "Easier" to Follow

### Core Principles

**The Golden Rule**: Write prompts as if for a "very smart but literal colleague."

### Cognitive Load Reduction Techniques

#### 1. Single-Task Focus
```
BAD (multiple goals):
"Proofread this article, translate it to Spanish, and format it as HTML"

GOOD (decomposed):
Step 1: "Proofread this article for grammar errors only"
Step 2: "Translate this proofread text to Spanish"
Step 3: "Format this Spanish text as HTML"
```

#### 2. Explicit Output Templates
```
Complete this template exactly:

NAME: [extract full name]
DATE: [extract date in YYYY-MM-DD format]
AMOUNT: [extract monetary amount as number only]

Input: "John Smith paid $150.00 on March 15, 2024"
```

#### 3. Positive Instructions Over Negations
```
HARDER TO FOLLOW:
"Don't include any personal opinions or subjective statements"

EASIER TO FOLLOW:
"Include only factual, verifiable information from the source"
```

#### 4. Concrete Over Abstract
```
ABSTRACT:
"Write in a professional tone"

CONCRETE:
"Write in third person, use complete sentences, avoid contractions"
```

### The 26 Principles (57% accuracy improvement)
Research identified principles that boost accuracy by 57%+ on LLaMA models:
1. Use clear, specific language
2. Break complex tasks into steps
3. Use "Let's think step by step" selectively
4. Provide examples matching desired output
5. Use consistent formatting throughout

### Prompt Scaffolding Template
```
<context>
[Background information the model needs]
</context>

<task>
[Single, clear objective]
</task>

<constraints>
- [Specific limitation 1]
- [Specific limitation 2]
</constraints>

<format>
[Exact output structure expected]
</format>

<examples>
Input: [example input]
Output: [example output]
</examples>

Now process this input:
[actual input]
```

---

## 6. Edge/Mobile AI Deployment Techniques

### Hardware Constraints
| Device Type | Typical RAM | Model Size Limit | Tokens/Second |
|-------------|-------------|------------------|---------------|
| Mobile (phone) | 4-8GB | 1-3B | 5-15 |
| Consumer laptop | 8-16GB | 7-8B | 15-30 |
| Gaming PC | 16-32GB | 13-30B | 20-50 |

### Quantization for Prompting
Models quantized to lower precision need **simpler, more explicit prompts**:
- INT8 models: Use clearer instructions, more examples
- INT4 models: Stick to simple tasks, avoid nuanced reasoning

### LoRA Adapters for Task-Specific Prompting
Fine-tune tiny adapters for specific prompt patterns:
```python
# A 1.5B model + LoRA for summarization
# can outperform a 7B general-purpose model
```

### Hybrid Cloud-Edge Strategy
```
On-device (small model):
- Intent classification
- Simple extractions
- Response formatting

Cloud (large model):
- Complex reasoning
- Multi-step planning
- Knowledge synthesis
```

### Key Metrics to Optimize
- **Time-to-First-Token (TTFT)**: Minimize prompt length
- **Tokens-Per-Second (TPS)**: Prefer shorter outputs
- **Memory footprint**: Compress prompts, limit context

---

## 7. Hallucination Reduction Techniques

### Why Small Models Hallucinate More
- Smaller knowledge base
- Less calibration training
- Weaker uncertainty awareness

**Key insight from OpenAI**: "It can be easier for a small model to know its limits. A small model which knows no Maori can simply say 'I don't know' whereas a model that knows some Maori has to determine its confidence."

### Practical Mitigation Strategies

#### 1. RAG (Retrieval-Augmented Generation)
Externalize knowledge to reduce parametric reliance:
```
Given these documents:
<doc1>{retrieved_content_1}</doc1>
<doc2>{retrieved_content_2}</doc2>

Answer the question using ONLY information from these documents.
If the answer is not in the documents, say "Information not available."

Question: {user_question}
```

**Benefit**: Smaller models + RAG can match larger models on knowledge tasks.

#### 2. Program-Aided Language Models (PAL)
Offload calculations to code interpreters:
```
Problem: "What is 17% of 4,523?"

# Generate Python code instead of calculating
```python
result = 0.17 * 4523
print(result)  # 769.91
```

Small models excel at generating the plan but fail at execution.
```

**Results**: PAL solve rates dramatically higher than direct calculation.

#### 3. Self-Verification Loop
```
Step 1: Generate answer
Step 2: "Review this answer. Is it factually supported? List any claims that need verification."
Step 3: For each uncertain claim, either verify or mark as uncertain
```

**Limitation**: Small models may lack the capability to verify their own outputs effectively. Consider using a separate verification step or external validation.

#### 4. Constrain Response Scope
```
Answer using ONLY:
- Direct quotes from the provided text
- Simple logical inferences from those quotes
- "Unknown" for anything else

Do not:
- Add information from general knowledge
- Make assumptions beyond the text
- Speculate about unstated facts
```

#### 5. Confidence Calibration
```
After your answer, rate your confidence:
- HIGH: Answer is directly stated in provided context
- MEDIUM: Answer is a reasonable inference from context
- LOW: Answer requires knowledge beyond provided context

If LOW, reconsider whether to provide the answer.
```

---

## Synthesis: The Small Model Prompting Framework

### Core Philosophy
**"Reduce cognitive load through structure, explicitness, and external support."**

### Decision Tree for Small Model Tasks

```
Is the task complex?
├── YES: Decompose into sub-tasks (Least-to-Most or DecomP)
│   └── Each sub-task should be simple enough for 7B model
└── NO: Use simple direct prompting with examples

Does it require reasoning?
├── YES: Use PAL (code generation) or constrained step-by-step
│   └── Avoid free-form Chain-of-Thought
└── NO: Direct extraction/classification

Does it need external knowledge?
├── YES: Use RAG with explicit sourcing constraints
│   └── "Answer ONLY from provided documents"
└── NO: Verify model has reliable training on topic

Does it need structured output?
├── YES: Use grammar-constrained decoding OR explicit templates
│   └── Consider SLOT post-processing for reliability
└── NO: Still provide format guidance
```

### The Ideal Small Model Prompt Structure

```
[ROLE - optional, keep brief]
You are a data extraction assistant.

[CONTEXT - essential information only]
<context>
{compressed_relevant_context}
</context>

[TASK - single, clear objective]
Extract the person's name and birthdate from the context.

[FORMAT - explicit structure]
Output exactly:
NAME: [full name]
BIRTHDATE: [YYYY-MM-DD or "not found"]

[EXAMPLES - 2-3 simple cases]
Example:
Context: "John Smith was born on March 5, 1990 in Seattle."
NAME: John Smith
BIRTHDATE: 1990-03-05

[CONSTRAINTS - what NOT to do, stated positively]
- Use only information from the provided context
- If information is missing, output "not found"
- Do not infer or guess

[INPUT]
Context: {actual_input}
```

---

## Quick Reference: Techniques by Model Size

| Technique | 3B | 7B | 13B | Notes |
|-----------|:--:|:--:|:---:|-------|
| Zero-shot | Limited | OK | Good | Add examples for 3B |
| Few-shot (3 examples) | Good | Good | Good | Sweet spot |
| Standard CoT | Hurts | Hurts | Mixed | Avoid for <13B |
| Least-to-Most | Good | Good | Good | Better than CoT |
| Decomposed Prompting | Good | Best | Good | Excellent for complex |
| PAL (code generation) | OK | Good | Good | Great for math |
| Grammar constraints | Essential | Helpful | Optional | SLOT for reliability |
| RAG | Essential | Helpful | Helpful | Compensates for size |
| XML/structured prompts | Helpful | Helpful | Good | Reduces confusion |

---

## Sources

- [Practical prompt engineering for smaller LLMs - web.dev](https://web.dev/articles/practical-prompt-engineering)
- [LLMLingua: Innovating LLM efficiency with prompt compression - Microsoft Research](https://www.microsoft.com/en-us/research/blog/llmlingua-innovating-llm-efficiency-with-prompt-compression/)
- [Prompt Compression for Large Language Models: A Survey - arXiv](https://arxiv.org/abs/2410.12388)
- [Chain-of-Thought Prompting - Learn Prompting](https://learnprompting.org/docs/intermediate/chain_of_thought)
- [Least-to-Most Prompting - arXiv](https://arxiv.org/abs/2205.10625)
- [Decomposed Prompting - arXiv](https://arxiv.org/abs/2210.02406)
- [PAL: Program-aided Language Models - arXiv](https://arxiv.org/abs/2211.10435)
- [Self-Consistency Prompting - Prompt Engineering Guide](https://www.promptingguide.ai/techniques/consistency)
- [Use XML tags to structure prompts - Anthropic Claude Docs](https://docs.anthropic.com/en/docs/use-xml-tags)
- [A Guide to Structured Outputs Using Constrained Decoding](https://www.aidancooper.co.uk/constrained-decoding/)
- [Boosting LLM Reasoning: Push the Limits of Few-shot Learning - arXiv](https://arxiv.org/html/2312.08901v2/)
- [From Prompts to Templates: A Systematic Prompt Template Analysis - arXiv](https://arxiv.org/html/2504.02052v2)
- [A Review on Edge Large Language Models - arXiv](https://arxiv.org/html/2410.11845v1)
- [Knowledge Distillation of Large Language Models - PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC12634706/)
- [Distilling Step-by-Step - Google Research](https://research.google/blog/distilling-step-by-step-outperforming-larger-language-models-with-less-training-data-and-smaller-model-sizes/)
- [LLM Hallucinations in 2025 - Lakera](https://www.lakera.ai/blog/guide-to-hallucinations-in-large-language-models)
- [Why Language Models Hallucinate - OpenAI](https://openai.com/index/why-language-models-hallucinate/)
- [Retrieval Augmented Generation - Prompt Engineering Guide](https://www.promptingguide.ai/techniques/rag)
- [26 Principles for Prompt Engineering - Codingscape](https://codingscape.com/blog/26-principles-for-prompt-engineering-to-increase-llm-accuracy)
