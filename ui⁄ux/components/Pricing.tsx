import { Button } from "./ui/button";
import { Card } from "./ui/card";
import { Check } from "lucide-react";

const plans = [
  {
    name: "Free",
    price: "$0",
    description: "Perfect for trying out BlurFace",
    features: [
      "5 recordings per month",
      "Up to 5 minutes per video",
      "720p resolution",
      "Basic face detection",
      "MP4 export",
      "Local processing"
    ],
    cta: "Get Started",
    highlighted: false
  },
  {
    name: "Pro",
    price: "$19",
    period: "/month",
    description: "For professionals and creators",
    features: [
      "Unlimited recordings",
      "Unlimited video length",
      "1080p resolution",
      "Advanced AI detection",
      "All export formats",
      "Custom blur settings",
      "Priority support",
      "Remove watermark"
    ],
    cta: "Start Free Trial",
    highlighted: true
  },
  {
    name: "Team",
    price: "$49",
    period: "/month",
    description: "For teams and organizations",
    features: [
      "Everything in Pro",
      "Up to 10 team members",
      "4K resolution",
      "Batch processing",
      "Team management",
      "Advanced analytics",
      "API access",
      "Dedicated support"
    ],
    cta: "Contact Sales",
    highlighted: false
  }
];

export function Pricing() {
  return (
    <section id="pricing" className="py-20 px-4 bg-gray-50">
      <div className="container mx-auto">
        <div className="text-center mb-16">
          <h2 className="mb-4">Simple, Transparent Pricing</h2>
          <p className="text-xl text-gray-600 max-w-2xl mx-auto">
            Choose the perfect plan for your needs. All plans include our core privacy features.
          </p>
        </div>
        
        <div className="grid md:grid-cols-3 gap-8 max-w-6xl mx-auto">
          {plans.map((plan, index) => (
            <Card 
              key={index} 
              className={`p-8 relative ${plan.highlighted ? 'shadow-xl border-2 border-blue-600 scale-105' : ''}`}
            >
              {plan.highlighted && (
                <div className="absolute -top-4 left-1/2 -translate-x-1/2 px-4 py-1 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-full text-sm">
                  Most Popular
                </div>
              )}
              
              <div className="text-center mb-6">
                <h3 className="mb-2">{plan.name}</h3>
                <div className="flex items-baseline justify-center gap-1 mb-2">
                  <span className="text-4xl">{plan.price}</span>
                  {plan.period && <span className="text-gray-600">{plan.period}</span>}
                </div>
                <p className="text-gray-600">{plan.description}</p>
              </div>
              
              <Button 
                className="w-full mb-6" 
                variant={plan.highlighted ? "default" : "outline"}
              >
                {plan.cta}
              </Button>
              
              <ul className="space-y-3">
                {plan.features.map((feature, featureIndex) => (
                  <li key={featureIndex} className="flex items-start gap-3">
                    <Check className="w-5 h-5 text-green-600 flex-shrink-0 mt-0.5" />
                    <span className="text-gray-600">{feature}</span>
                  </li>
                ))}
              </ul>
            </Card>
          ))}
        </div>
      </div>
    </section>
  );
}
