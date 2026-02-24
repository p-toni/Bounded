# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::GraphGranularity do
  def create_graph(user_id: "user_v1", title: "Topic")
    source = Source.create!(url: "https://example.com/#{SecureRandom.hex(4)}")
    topic = Topic.create!(user_id: user_id, title: title, source_id: source.id)
    GraphVersion.create!(topic_id: topic.id, version_int: 1, schema_version: "1.0.0")
  end

  def add_node(graph, node_id)
    Node.create!(
      graph_version_id: graph.id,
      node_id: node_id,
      label: "Node #{node_id}",
      definition_1s: "Definition for #{node_id}",
      schema_version: "1.0.0"
    )
  end

  def add_edge(graph, edge_id, from_id, to_id, anchor: false)
    Edge.create!(
      graph_version_id: graph.id,
      edge_id: edge_id,
      from_node_id: from_id,
      to_node_id: to_id,
      edge_type: "causal",
      mechanism_json: { mediator: from_id, observable: to_id, failure_mode: "none", intervention: "check" },
      is_anchor: anchor,
      schema_version: "1.0.0"
    )
  end

  it "passes when graph is within v0 bounds" do
    graph = create_graph
    %w[n1 n2 n3 n4 n5 n6 n7].each { |id| add_node(graph, id) }
    add_edge(graph, "e1", "n1", "n2", anchor: true)
    add_edge(graph, "e2", "n2", "n3", anchor: true)
    add_edge(graph, "e3", "n3", "n4", anchor: true)
    add_edge(graph, "e4", "n4", "n5", anchor: true)
    add_edge(graph, "e5", "n5", "n6", anchor: true)

    result = described_class.validate(graph_version: graph)
    expect(result[:ok]).to eq(true)
    expect(result[:errors]).to eq([])
  end

  it "fails when anchor counts are outside required range" do
    graph = create_graph
    %w[n1 n2 n3].each { |id| add_node(graph, id) }
    add_edge(graph, "e1", "n1", "n2", anchor: true)
    add_edge(graph, "e2", "n2", "n3", anchor: false)

    result = described_class.validate(graph_version: graph)
    expect(result[:ok]).to eq(false)
    expect(result[:errors].join(" ")).to include("Anchor edge count")
  end

  it "blocks oversized graphs until progression graph level is unlocked" do
    graph = create_graph
    %w[n1 n2 n3 n4 n5 n6 n7 n8].each { |id| add_node(graph, id) }
    add_edge(graph, "e1", "n1", "n2", anchor: true)
    add_edge(graph, "e2", "n2", "n3", anchor: true)
    add_edge(graph, "e3", "n3", "n4", anchor: true)
    add_edge(graph, "e4", "n4", "n5", anchor: true)
    add_edge(graph, "e5", "n5", "n6", anchor: true)
    add_edge(graph, "e6", "n1", "n3", anchor: true)
    add_edge(graph, "e7", "n2", "n4", anchor: true)

    starter = described_class.validate(graph_version: graph, progression: { graph_level: 0, tier_name: "edge_scout" })
    expect(starter[:ok]).to eq(false)
    expect(starter[:errors].join(" ")).to include("graph_level 0")

    unlocked = described_class.validate(graph_version: graph, progression: { graph_level: 1, tier_name: "map_apprentice" })
    expect(unlocked[:ok]).to eq(true)
    expect(unlocked[:stats][:graph_level]).to eq(1)
  end
end
