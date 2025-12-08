# Diataxis Framework Guide for Documentation

## Overview

Diataxis is a systematic approach to organizing technical documentation around four fundamental user needs. Each type serves a distinct purpose and should be kept separate.

## The Four Documentation Types

### 1. **Tutorials** (Learning-oriented)

**Purpose**: Teaching beginners through hands-on practice  
**User need**: "I want to learn by doing"

**Characteristics**:

- Step-by-step lessons with a specific outcome
- Reader is "on rails" - no decision-making required
- Provides sample data, sandbox environments
- Written as if an instructor is guiding the learner
- Focuses on practical skills, not comprehensive coverage

**Structure**: Introduction → Prerequisites → Steps (numbered) → Conclusion  
**Example**: "Getting Started with [Tool]", "Your First Project"

---

### 2. **How-To Guides** (Task-oriented)

**Purpose**: Solving specific real-world problems  
**User need**: "I want to accomplish a specific goal"

**Characteristics**:

- Assumes reader is already competent with basics
- Focused on practical application and problem-solving
- Recipe-like format addressing specific scenarios
- Shows "how" not "why"

**Structure**: Problem statement → Prerequisites → Steps → Variations/Edge cases  
**Example**: "How to configure logging", "Troubleshooting deployment problems"

---

### 3. **Reference** (Information-oriented)

**Purpose**: Providing technical facts for lookup  
**User need**: "I need accurate information about something"

**Characteristics**:

- Dry, factual, and comprehensive
- Neutral tone - no explanations or instructions
- Structured like the product architecture itself
- Like a dictionary or map - consulted, not read cover-to-cover
- Accurate, complete, and reliable

**Structure**: Mirrors product structure (e.g., API endpoints, parameters, classes)  
**Example**: API documentation, command references, configuration options

---

### 4. **Explanation** (Understanding-oriented)

**Purpose**: Providing context and deepening understanding  
**User need**: "I want to understand why and how things work"

**Characteristics**:

- Discusses concepts, design decisions, and trade-offs
- Connects ideas and provides background
- Answers "why" questions
- Can be discursive and exploratory

**Structure**: Concept introduction → Context → Deep dive → Implications  
**Example**: "Understanding our architecture", "Why we chose X over Y"

---

## The Diataxis Map

```text
                PRACTICAL
                    |
        TUTORIALS   |   HOW-TO GUIDES
    (learning)      |      (tasks)
                    |
STUDY ----------------------------- WORK
                    |
    EXPLANATION |   REFERENCE
   (understanding)  |   (information)
                    |
              THEORETICAL
```

---

## Organization Rules

### Directory Structure

```text
docs/
├── tutorials/
├── how-to-guides/
├── reference/
└── explanation/
```

### Key Principles

1. **Keep types distinct** - Don't mix tutorials with reference material
2. **One purpose per document** - Each document serves exactly one user need
3. **Cross-link freely** - Reference across types, but don't duplicate content
4. **User journey aware** - Users naturally progress: Tutorial → How-to → Reference → Explanation

### Common Anti-Patterns to Avoid

❌ Explaining concepts in tutorials (put in Explanation)  
❌ Including all technical details in how-to guides (put in Reference)  
❌ Writing reference docs that teach (keep them factual)  
❌ Making tutorials that require decision-making (keep them on-rails)

---

## When Categorizing Documents

Ask these questions:

1. **Is the user learning?** → Tutorial
2. **Is the user working on a specific task?** → How-to Guide
3. **Does the user need to look up facts?** → Reference
4. **Does the user want to understand why?** → Explanation

---

## Tips for AI Assistants

When working with documentation in this repo:

- **Identify** the document type before editing or creating content
- **Maintain** the separation between types - don't blend them
- **Use phantom links** - link to docs that should exist but don't yet
- **Structure follows architecture** - especially for reference docs
- **Keep reference neutral** - no opinions, just facts
- **Make tutorials complete** - they should work start to finish
- **Focus how-tos on solutions** - not on teaching fundamentals
- **Let explanations explore** - they can be discursive

The goal is to serve different user needs at different times in their journey with the product.
