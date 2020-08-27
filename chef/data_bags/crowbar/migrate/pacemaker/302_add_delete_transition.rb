def upgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["config"]["transition_list"] = template_deployment["config"]["transition_list"]
  deployment["config"]["transitions"] = template_deployment["config"]["transitions"]
  return attrs, deployment
end

def downgrade(template_attrs, template_deployment, attrs, deployment)
  deployment["config"]["transition_list"] = template_deployment["config"]["transition_list"]
  deployment["config"]["transitions"] = template_deployment["config"]["transitions"]
  return attrs, deployment
end
