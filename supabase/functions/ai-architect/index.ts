import "https://deno.land/x/xhr@0.1.0/mod.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.81.1";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface CanvasNodeType {
  id: string;
  system_name: string;
  display_label: string;
  description: string;
  category: string;
  icon: string;
  color_class: string;
  order_score: number;
  is_active: boolean;
  is_legacy: boolean;
}

// Dynamic helper functions
function buildXPositions(nodeTypes: CanvasNodeType[]): Record<string, number> {
  // Manual overrides for types that share the same order_score
  const MANUAL_OVERRIDES: Record<string, number> = {
    NOTES: 50,
    ZONE: 50,
    LABEL: 50,
    PROJECT: 150,
    REQUIREMENT: 300,
    STANDARD: 450,
    SECURITY: 600,
    TECH_STACK: 750,
  };

  const result: Record<string, number> = {};
  nodeTypes.forEach(nt => {
    result[nt.system_name] = MANUAL_OVERRIDES[nt.system_name] ?? nt.order_score * 3;
  });
  return result;
}

function buildNodeTypePrompt(nodeTypes: CanvasNodeType[]): string {
  const activeTypes = nodeTypes.filter(nt => nt.is_active && !nt.is_legacy);
  const legacyTypes = nodeTypes.filter(nt => nt.is_legacy);
  
  let prompt = 'NODE TYPES (use exact values):\n';
  activeTypes.forEach(nt => {
    prompt += `- ${nt.system_name}: ${nt.description || nt.display_label}\n`;
  });
  
  if (legacyTypes.length > 0) {
    prompt += `\nLEGACY TYPES (avoid using for new nodes): ${legacyTypes.map(lt => lt.system_name).join(', ')}\n`;
  }
  
  return prompt;
}

function buildPositioningPrompt(nodeTypes: CanvasNodeType[]): string {
  const groups = new Map<number, { types: string[], xPos: number }>();
  
  nodeTypes.filter(nt => nt.is_active).forEach(nt => {
    const rank = Math.floor(nt.order_score / 100);
    const xPos = nt.order_score + Math.floor(nt.order_score * 0.5);
    if (!groups.has(rank)) groups.set(rank, { types: [], xPos });
    groups.get(rank)!.types.push(nt.system_name);
    groups.get(rank)!.xPos = xPos; // Use last one in group
  });
  
  let prompt = 'POSITIONING RULES:\n';
  prompt += '- X-axis positions by node type:\n';
  
  Array.from(groups.entries())
    .sort((a, b) => a[0] - b[0])
    .forEach(([rank, data]) => {
      prompt += `  * ${data.types.join(', ')}: x=${data.xPos}\n`;
    });
  
  prompt += '- Do NOT set x or y values — positioning is handled automatically.\n';
  
  return prompt;
}

function buildFlowHierarchyPrompt(nodeTypes: CanvasNodeType[]): string {
  const groups = new Map<number, string[]>();
  nodeTypes.filter(nt => nt.is_active && !nt.is_legacy).forEach(nt => {
    const rank = Math.floor(nt.order_score / 100);
    if (!groups.has(rank)) groups.set(rank, []);
    groups.get(rank)!.push(nt.system_name);
  });
  
  let prompt = 'FLOW HIERARCHY (all edges must flow left to right):\n';
  Array.from(groups.entries())
    .sort((a, b) => a[0] - b[0])
    .forEach(([rank, types]) => {
      const xPos = rank * 100 + Math.floor(rank * 50);
      prompt += `Level ${rank} (x=${xPos}): ${types.join(', ')}\n`;
    });
  
  return prompt;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { 
      description, 
      existingNodes, 
      existingEdges, 
      drawEdges = true,
      attachedContext,
      projectId,
      shareToken,
      canvasId
    } = body;
    
    console.log('[ai-architect] canvasId:', canvasId || 'default');

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const authHeader = req.headers.get('Authorization');
    
    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      auth: { autoRefreshToken: false, persistSession: false },
      global: { headers: authHeader ? { Authorization: authHeader } : {} },
    });

    // ========== PROJECT ACCESS VALIDATION ==========
    if (projectId) {
      const { data: project, error: accessError } = await supabase.rpc('get_project_with_token', {
        p_project_id: projectId,
        p_token: shareToken || null
      });

      if (accessError || !project) {
        console.error('[ai-architect] Access denied:', accessError);
        return new Response(JSON.stringify({ error: 'Access denied' }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      
      console.log('[ai-architect] Access validated for project:', projectId);
    }
    // ========== END VALIDATION ==========

    // Fetch node types from database for dynamic configuration
    const { data: nodeTypesData, error: nodeTypesError } = await supabase.rpc('get_canvas_node_types', {
      p_include_legacy: true
    });

    if (nodeTypesError) {
      console.error('[ai-architect] Failed to fetch node types:', nodeTypesError);
      throw new Error('Failed to fetch node types configuration');
    }

    const nodeTypes: CanvasNodeType[] = nodeTypesData || [];
    console.log(`[ai-architect] Loaded ${nodeTypes.length} node types from database`);

    // Build dynamic X_POSITIONS from database
    const X_POSITIONS = buildXPositions(nodeTypes);
    
    const GOOGLE_AI_API_KEY = Deno.env.get('GOOGLE_AI_API_KEY');
    
    if (!GOOGLE_AI_API_KEY) {
      throw new Error('GOOGLE_AI_API_KEY not configured');
    }

    console.log('Generating architecture for:', description);

    // Build dynamic prompts from database
    const positioningPrompt = buildPositioningPrompt(nodeTypes);
    const nodeTypePrompt = buildNodeTypePrompt(nodeTypes);
    const flowHierarchyPrompt = buildFlowHierarchyPrompt(nodeTypes);

    const systemPrompt = `You are an expert software architect. Generate a comprehensive application architecture based on the user's description.

${positioningPrompt}

${nodeTypePrompt}

${flowHierarchyPrompt}

${drawEdges ? `EDGES: Be selective. Maximum 2-3 edges per node. Do NOT connect the root project node to every component — only connect it to top-level entry points (pages, main services). Avoid redundant or transitive connections. All edges must flow LEFT to RIGHT (lower level to higher level). CRITICAL: The source and target fields in every edge must be character-for-character identical to the label field of the corresponding node. Copy the label exactly — same capitalization, same spacing, same punctuation.
Valid connection patterns:
- PROJECT → PAGE, TECH_STACK, REQUIREMENT, STANDARD
- PAGE → WEB_COMPONENT
- WEB_COMPONENT → HOOK_COMPOSABLE
- HOOK_COMPOSABLE → API_SERVICE
- API_SERVICE → API_ROUTER
- API_ROUTER → API_MIDDLEWARE, API_CONTROLLER
- API_CONTROLLER → EXTERNAL_SERVICE, DATABASE
- DATABASE → SCHEMA
- SCHEMA → TABLE` : 'DO NOT return any edges in your response. The user has disabled edge generation.'}

Return ONLY valid JSON with this structure:
{
  "nodes": [
    {
      "label": "Node Name",
      "type": "${nodeTypes.filter(nt => nt.is_active && !nt.is_legacy).map(nt => nt.system_name).join('|')}",
      "subtitle": "Brief subtitle",
      "description": "Detailed description",
      "x": 100,
      "y": 100
    }
  ]${drawEdges ? `,
  "edges": [
    {
      "source": "Source Node Label",
      "target": "Target Node Label",
      "relationship": "fetches data from"
    }
  ]` : ''}
}

Be comprehensive. Include all major components, pages, APIs, databases, and external services.
Use clear, descriptive names. Be specific about what each component does.`;

    // Build enriched system prompt with attached context
    let enrichedSystemPrompt = systemPrompt;
    
    if (attachedContext) {
      const contextParts: string[] = [];

      if (attachedContext.projectMetadata) {
        contextParts.push("PROJECT METADATA: included");
      }
      if (attachedContext.artifacts?.length) {
        contextParts.push(`ARTIFACTS: ${attachedContext.artifacts.length} artifacts attached`);
      }
      if (attachedContext.chatSessions?.length) {
        contextParts.push(`CHAT SESSIONS: ${attachedContext.chatSessions.length} sessions attached`);
      }
      if (attachedContext.requirements?.length) {
        contextParts.push(`REQUIREMENTS: ${attachedContext.requirements.length} requirements attached`);
      }
      if (attachedContext.standards?.length) {
        contextParts.push(`STANDARDS: ${attachedContext.standards.length} standards attached`);
      }
      if (attachedContext.techStacks?.length) {
        contextParts.push(`TECH STACKS: ${attachedContext.techStacks.length} tech stacks attached`);
      }
      if (attachedContext.canvasNodes?.length) {
        contextParts.push(`CANVAS NODES: ${attachedContext.canvasNodes.length} nodes attached`);
      }
      if (attachedContext.canvasEdges?.length) {
        contextParts.push(`CANVAS EDGES: ${attachedContext.canvasEdges.length} edges attached`);
      }
      if (attachedContext.canvasLayers?.length) {
        contextParts.push(`CANVAS LAYERS: ${attachedContext.canvasLayers.length} layers attached`);
      }
      if (attachedContext.files?.length) {
        contextParts.push(`REPOSITORY FILES: ${attachedContext.files.length} files attached`);
      }
      if (attachedContext.databases?.length) {
        const dbTypes = attachedContext.databases.reduce((acc: Record<string, number>, d: any) => {
          acc[d.type] = (acc[d.type] || 0) + 1;
          return acc;
        }, {});
        const dbSummary = Object.entries(dbTypes).map(([t, c]) => `${c} ${t}s`).join(', ');
        contextParts.push(`DATABASE SCHEMAS: ${attachedContext.databases.length} items (${dbSummary})`);
      }

      if (contextParts.length > 0) {
        const jsonString = JSON.stringify(attachedContext, null, 2);
        const truncatedJson = jsonString.length > 50000
          ? jsonString.slice(0, 50000) + "\n...[truncated for length]"
          : jsonString;

        enrichedSystemPrompt = `${systemPrompt}\n\n===== ATTACHED PROJECT CONTEXT =====\n${contextParts.join("\n")}\n\n===== FULL CONTEXT DATA =====\n${truncatedJson}\n\nPlease use the above context to inform your architecture design. The context includes full object data with all properties and content.`;
      }
    }
    
    // Build context string for existing architecture
    let existingContextInfo = '';
    
    if (existingNodes && existingNodes.length > 0) {
      const nodesList = existingNodes.map((n: any) => 
        `${n.data.label} (${n.data.type}): ${n.data.description || 'No description'}`
      ).join('\n');
      existingContextInfo += `\n\nEXISTING NODES (${existingNodes.length}):\n${nodesList}\n\n⚠️ CRITICAL: DO NOT recreate any of the existing nodes listed above. ONLY generate NEW nodes that complement and augment the existing architecture. If a node with similar functionality already exists, DO NOT create a duplicate. Focus on filling gaps and adding missing components.`;
    }

    if (existingEdges && existingEdges.length > 0) {
      const edgesList = existingEdges.map((e: any) => 
        `${e.source} → ${e.target}${e.data?.label ? ` (${e.data.label})` : ''}`
      ).join('\n');
      existingContextInfo += `\n\nEXISTING CONNECTIONS (${existingEdges.length}):\n${edgesList}`;
    }

    const userPrompt = `Generate a complete application architecture for: ${description}${existingContextInfo}`;

    const response = await fetch(
  `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${Deno.env.get('GOOGLE_AI_API_KEY')}`,
  {
        method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: enrichedSystemPrompt }] },
      contents: [
        { role: 'user', parts: [{ text: userPrompt }] }
      ],
      generationConfig: { temperature: 0.7 },
    }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('AI API error:', response.status, errorText);
      throw new Error(`AI API error: ${response.status}`);
    }

    const data = await response.json();
    const content = data.candidates?.[0]?.content?.parts?.[0]?.text;
    
    console.log('AI response:', content);

    // Extract JSON from response (may be wrapped in markdown code blocks)
    let jsonMatch = content.match(/```json\n?([\s\S]*?)\n?```/);
    let architecture;
    
    if (jsonMatch) {
      architecture = JSON.parse(jsonMatch[1]);
    } else {
      // Try to parse directly
      architecture = JSON.parse(content);
    }

  // Post-process nodes: assign IDs and fix X positions
if (architecture.nodes) {
  const nodeMap = new Map<string, string>();
  const typeYCounters: Record<string, number> = {};
  const Y_START = 100;
  const Y_SPACING = 150;

  architecture.nodes = architecture.nodes.map((node: any, index: number) => {
    const id = `node-${index}-${node.label.toLowerCase().replace(/\s+/g, '-').replace(/[^a-z0-9-]/g, '')}`;
    nodeMap.set(node.label, id);

    const x = X_POSITIONS[node.type] ?? 700;
    const yIndex = typeYCounters[node.type] ?? 0;
    typeYCounters[node.type] = yIndex + 1;
    const y = Y_START + yIndex * Y_SPACING;

    return { ...node, id, x, y };
  });

  // Rewrite edges to use resolved IDs, drop any that can't be matched
if (architecture.edges) {
  architecture.edges = architecture.edges
    .map((edge: any) => {
      const sourceId = nodeMap.get(edge.source);
      const targetId = nodeMap.get(edge.target);
       if (!sourceId || !targetId) {
        console.warn(`[ai-architect] Unresolved edge: "${edge.source}" → "${edge.target}"`);
        console.warn(`[ai-architect] Available labels:`, Array.from(nodeMap.keys()));
        return null;
      }
      return {
        ...edge,
        source: sourceId,  // overwrite with resolved ID
        target: targetId,  // overwrite with resolved ID
      };
    })
    .filter(Boolean);
}
}

    console.log('Parsed architecture:', architecture);

    return new Response(JSON.stringify(architecture), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Error in ai-architect function:', error);
    return new Response(JSON.stringify({ 
      error: error instanceof Error ? error.message : 'Unknown error',
      details: error instanceof Error ? error.stack : undefined
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
